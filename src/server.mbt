// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
struct Server {
  tools : Map[String, Tool]
  in_channel : @channel.T[Message]
  out_channel : @channel.T[Message]
  mut running : Bool
  mut capabilities : Json
  mut clientInfo : Json
  callbacks : Map[Id, @channel.T[Message]]
  // Currently try to use id as key for callbacks.
  // Maybe we need to have UUID for more certainty.
  mut used_id : UInt
}

///|
pub fn new() -> Server {
  Server::{
    tools: {},
    in_channel: @channel.make(size=10),
    out_channel: @channel.make(size=10),
    running: false,
    capabilities: {},
    clientInfo: {},
    callbacks: {},
    used_id: 0,
  }
}

///|
pub fn serve(self : Server) -> Result[Unit, Unit] {
  self.running = true
  // read from stdin for input channel
  @promise.spawn(async fn(_defer) {
    while self.running {
      try {
        let message = @io.read_line().await!!()
          |> @json.parse!()
          |> @json.from_json!()
        self.in_channel.push!!(message)
      } catch {
        @streams.Closed => break
        e => {
          @io.println(e.to_string(), stream=@io.stderr).await!!()
          break
        }
      }
    }
  })
  |> ignore
  // write to stdout for output channel
  @promise.spawn(async fn(_defer) {
    while true {
      let message = self.out_channel.pop!!()
      @io.println(message.to_json() |> @json.stringify).await!!()
    }
  })
  |> ignore
  // handle messages
  @promise.spawn(async fn(defer) {
    defer(fn() { self.running = false })
    guard let Request(
      id~,
      method_="initialize",
      params={
        "protocolVersion": "2024-11-05",
        "capabilities": capabilities,
        "clientInfo": clientInfo,
        ..
      }
    ) = self.in_channel.pop!!() else {
      message =>
        @io.println(
          "Invalid initialization request \{message}",
          stream=@io.stderr,
        ).await!!()
    }
    if id is Number(id) {
      self.used_id = @math.maximum(self.used_id, id.to_uint())
    }
    let response = Response(
      id~,
      payload=Ok({
        "protocolVersion": "2024-11-05",
        "capabilities": { "logging": {}, "tools": { "listChanged": true } },
        "serverInfo": { "name": "mcp-cli", "version": "0.1.0" },
      }),
    )
    self.out_channel.push!!(response)
    guard let Notification(method_="notifications/initialized", params=_) = self.in_channel.pop!!() else {
      message =>
        @io.println(
          "Invalid initializaiton notification \{message}",
          stream=@io.stderr,
        ).await!!()
    }
    self.capabilities = capabilities
    self.clientInfo = clientInfo
    while true {
      let message = self.in_channel.pop!!()
      @promise.spawn(async fn(_defer) {
        try {
          self.handle!!(message)
        } catch {
          error => @io.println(error.to_string(), stream=@io.stderr).await!!()
        } else {
          Some(response) => self.out_channel.push!!(response)
          None => ()
        }
      })
      |> ignore
    }
  })
  |> ignore
  @io.event_loop.run()
  Ok(())
}

///|
async fn handle(self : Server, message : Message) -> Message?! {
  // Check the used ids
  if message is Request(id=Number(id), ..) {
    self.used_id = @math.maximum(self.used_id, id.to_uint())
  }
  match message {
    Request(method_="tools/list", id~, ..) =>
      Some(
        Response(
          id~,
          payload=Ok({
            "tools": Array(
              self.tools
              .iter()
              .map(fn {
                (name, { description, inputSchema, .. }) =>
                  (
                    {
                      "name": String(name),
                      "description": String(description),
                      "inputSchema": inputSchema.to_json(),
                    } : Json)
              })
              .collect(),
            ),
          }),
        ),
      )
    Request(method_="tools/call", id~, params~) =>
      if params is { "name": String(name), "arguments": arguments, .. } &&
        self.tools.get(name) is Some(tool) {
        if not(tool.inputSchema.verify(arguments)) {
          return Some(
            Response(
              id~,
              payload=Err(RPCError::{
                code: -32602,
                message: "Failed to validate tool call argument",
                data: None,
              }),
            ),
          )
        }
        let { isError, payload } = (tool.cb)!!(arguments, self)
        return Some(
          Response(
            id~,
            payload=Ok({
              "isError": if isError {
                True
              } else {
                False
              },
              "content": match payload {
                Text(text~) => [{ "type": "text", "text": String(text) }]
                Image(data~, mimeType~) =>
                  [
                    {
                      "type": "image",
                      "data": String(data),
                      "mimeType": String(mimeType),
                    },
                  ]
                Resource(uri~, mimeType~, text~) =>
                  [
                    {
                      "type": "resource",
                      "uri": String(uri),
                      "mimeType": String(mimeType),
                      "text": String(text),
                    },
                  ]
              },
            }),
          ),
        )
      } else {
        return Some(
          Response(
            id~,
            payload=Err(RPCError::{
              code: -32602,
              message: "Failed to verify tool call payload",
              data: None,
            }),
          ),
        )
      }
    Request(method_="prompts/list", id~, ..) =>
      Some(Response(id~, payload=Ok({ "prompts": [] })))
    Request(method_="resources/list", id~, ..) =>
      Some(Response(id~, payload=Ok({ "resources": [] })))
    Request(method_="resources/templates/list", id~, ..) =>
      Some(Response(id~, payload=Ok({ "resourceTemplates": [] })))
    Response(id~, ..) as response => {
      if self.callbacks[id] is Some(channel) {
        @promise.spawn(fn(_dfer) { channel.push!!(response) }) |> ignore
      } else {
        @io.println(
          "Unexpected response for request \{id}: \{response}",
          stream=@io.stderr,
        ).await!!()
      }
      None
    }
    other => {
      @io.println("Unhandled \{other}", stream=@io.stderr) |> ignore
      None
    }
  }
}

///|
fn next_id(self : Server) -> UInt {
  let id = self.used_id + 1
  self.used_id = id
  id
}

///|
pub async fn log(
  self : Server,
  message : Json,
  level~ : LogLevel = Info
) -> Unit! {
  let notification = Notification(method_="notifications/message", params={
    "level": String(level.to_string().to_lower()),
    "data": message,
  })
  self.out_channel.push!!(notification)
}

///|
pub fn add_tool(
  self : Server,
  name~ : String,
  description~ : String,
  inputSchema~ : Schema,
  cb~ : async (Json, Server) -> Response!
) -> Unit {
  self.tools[name] = Tool::{ description, inputSchema, cb }
  if self.running {
    @promise.spawn(async fn(_defer) {
      self.out_channel.push!!(
        Notification(method_="notifications/tools/list_changed", params={}),
      )
    })
    |> ignore
  }
}

///|
pub fn remove_tool(self : Server, name : String) -> Unit {
  self.tools.remove(name)
  if self.running {
    @promise.spawn(async fn(_defer) {
      self.out_channel.push!!(
        Notification(method_="notifications/tools/list_changed", params={}),
      )
    })
    |> ignore
  }
}

///|
pub async fn list_roots(self : Server) -> Array[Root]! {
  if self.capabilities is { "roots": _, .. } && self.running {
    let channel = @channel.make(size=1)
    let id = Number(self.next_id().to_uint64().to_double())
    self.callbacks[id] = channel
    self.out_channel.push!!(Request(id~, method_="roots/list", params={}))
    let response = channel.pop!!()
    self.callbacks.remove(id)
    // TODO: better error handling
    guard let Response(payload~, ..) = response else {
      message => {
        @io.println(
          "Unexpected message for request roots/list: \{message}",
          stream=@io.stderr,
        ).await!!()
        return []
      }
    }
    guard let Ok({ "roots": Array(roots), .. }) = payload else {
      _ => {
        @io.println(
          "Unexpected payload for request roots/list",
          stream=@io.stderr,
        ).await!!()
        return []
      }
    }
    roots.map(fn {
      { "uri": String(uri), "name"? : name, .. } =>
        { uri, name: name.bind(Json::as_string) }
      _ => panic()
    })
  } else {
    []
  }
}
