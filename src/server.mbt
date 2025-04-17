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
  prompts : Map[String, Prompt]
  in_channel : @channel.T[Message]
  out_channel : @channel.T[Message]
  mut running : Bool
  mut capabilities : Json
  mut clientInfo : Json
  callbacks : Map[Id, @channel.T[Message]]
  random : @random.Rand
}

///|
pub fn new(seed : Bytes) -> Server {
  Server::{
    tools: {},
    prompts: {},
    in_channel: @channel.make(size=10),
    out_channel: @channel.make(size=10),
    running: false,
    capabilities: {},
    clientInfo: {},
    callbacks: {},
    random: @random.new(seed~),
  }
}

///|
pub fn serve(
  self : Server,
  stdin~ : &@stream.Reader,
  stdout~ : &@stream.Writer,
  stderr~ : &@stream.Writer
) -> Unit {
  let stdin = @stream.buffered_reader(stdin)
  self.running = true
  // read from stdin for input channel
  @promise.spawn(async fn(_defer) {
    while self.running {
      try {
        let message = stdin.read_line().await!()
          |> @json.parse!()
          |> @json.from_json!()
        self.in_channel.push!(message)
      } catch {
        e => {
          stderr.write("\{e}\n").await!()
          break
        }
      }
    }
  })
  |> ignore
  // write to stdout for output channel
  @promise.spawn(async fn(_defer) {
    while true {
      let message = self.out_channel.pop!()
      stdout.write("\{message.to_json() |> @json.stringify}\n").await!()
    }
  })
  |> ignore
  // handle messages
  @promise.spawn(async fn(defer) {
    defer(fn() { self.running = false })
    let request = self.in_channel.pop!()
    guard request is Request(id~, method_="initialize", params~) else {
      fail!("Invalid initialization request \{request}")
    }
    guard params
      is {
        "protocolVersion": "2024-11-05",
        "capabilities": capabilities,
        "clientInfo": clientInfo,
        ..
      } else {
      self.out_channel.push!(
        Response(
          id~,
          payload=Err({
            code: -32602,
            message: "Unsupported protocol version",
            data: Some({ "supported": ["2024-11-05"] }),
          }),
        ),
      )
    }
    let response = @rpc.Response(
      id~,
      payload=Ok({
        "protocolVersion": "2024-11-05",
        "capabilities": {
          "logging": {},
          "tools": { "listChanged": true },
          "prompts": { "listChanged": true },
        },
        "serverInfo": { "name": "mcp-cli", "version": "0.1.0" },
      }),
    )
    self.out_channel.push!(response)
    let notification = self.in_channel.pop!()
    guard notification
      is Notification(method_="notifications/initialized", params=_) else {
      fail!("Invalid initializaiton notification \{notification}")
    }
    self.capabilities = capabilities
    self.clientInfo = clientInfo
    while true {
      let message = self.in_channel.pop!()
      @promise.spawn(async fn(_defer) {
        try {
          self.handle!(message)
        } catch {
          error => self.log!(String(error.to_string()), level=Error)
        } else {
          Some(response) => self.out_channel.push!(response)
          None => ()
        }
      })
      |> ignore
    }
  })
  |> ignore
}

///|
async fn handle(self : Server, message : Message) -> Message?! {
  // Check the used ids
  match message {
    Request(method_="ping", id~, ..) => Some(Response(id~, payload=Ok({})))
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
        let { isError, payload } = (tool.cb)!(arguments, self)
        return Some(
          Response(
            id~,
            payload=Ok({
              "isError": if isError {
                True
              } else {
                False
              },
              "content": Array(
                payload.map(fn {
                  Text(text~) => { "type": "text", "text": String(text) }
                  Image(data~, mimeType~) =>
                    {
                      "type": "image",
                      "data": String(data),
                      "mimeType": String(mimeType),
                    }
                  Resource(uri~, mimeType~, text~) =>
                    {
                      "type": "resource",
                      "uri": String(uri),
                      "mimeType": String(mimeType),
                      "text": String(text),
                    }
                }),
              ),
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
      Some(
        Response(
          id~,
          payload=Ok({
            "prompts": Array(
              self.prompts
              .iter()
              .map(fn {
                (name, { description, arguments, .. }) =>
                  (
                    {
                      "name": String(name),
                      "description": String(description),
                      "arguments": Array(
                        arguments.map(fn {
                          { name, description, required } =>
                            {
                              "name": String(name),
                              "description": String(description.or("")),
                              "required": if required is Some(true) {
                                True
                              } else {
                                False
                              },
                            }
                        }),
                      ),
                    } : Json)
              })
              .collect(),
            ),
          }),
        ),
      )
    Request(method_="prompts/get", id~, params~) =>
      if params is { "name": String(name), "arguments": Object(arguments), .. } &&
        self.prompts.get(name) is Some(prompt) {
        for argument in prompt.arguments {
          if argument.required is Some(true) &&
            not(arguments.contains(argument.name)) {
            return Some(
              Response(
                id~,
                payload=Err(RPCError::{
                  code: -32602,
                  message: "Failed to validate prompt get argument due to missing argument \{argument.name}",
                  data: None,
                }),
              ),
            )
          }
        }
        let response = (prompt.cb)(arguments)
        return Some(
          Response(
            id~,
            payload=Ok({
              "messages": Array(
                response.map(fn {
                  { role, message: Text(text~) } =>
                    {
                      "role": match role {
                        User => "user"
                        Assistant => "assistant"
                      },
                      "content": { "type": "text", "text": String(text) },
                    }
                  { role, message: Image(data~, mimeType~) } =>
                    {
                      "role": match role {
                        User => "user"
                        Assistant => "assistant"
                      },
                      "content": {
                        "type": "image",
                        "data": String(data),
                        "mimeType": String(mimeType),
                      },
                    }
                  { role, message: Resource(uri~, mimeType~, text~) } =>
                    {
                      "role": match role {
                        User => "user"
                        Assistant => "assistant"
                      },
                      "content": {
                        "type": "resource",
                        "uri": String(uri),
                        "mimeType": String(mimeType),
                        "text": String(text),
                      },
                    }
                }),
              ),
            }),
          ),
        )
      } else {
        return Some(
          Response(
            id~,
            payload=Err(RPCError::{
              code: -32602,
              message: "Failed to validate prompt get payload",
              data: None,
            }),
          ),
        )
      }
    Request(method_="resources/list", id~, ..) =>
      Some(Response(id~, payload=Ok({ "resources": [] })))
    Request(method_="resources/templates/list", id~, ..) =>
      Some(Response(id~, payload=Ok({ "resourceTemplates": [] })))
    Response(id~, ..) as response => {
      if self.callbacks[id] is Some(channel) {
        @promise.spawn(fn(_dfer) { channel.push!(response) }) |> ignore
      } else {
        fail!("Unexpected response for request \{id}: \{response}")
      }
      None
    }
    other => {
      fail!("Unhandled \{other}")
      None
    }
  }
}

///|
pub async fn log(
  self : Server,
  message : Json,
  level~ : LogLevel = Info
) -> Unit {
  let notification = @rpc.Notification(method_="notifications/message", params={
    "level": String(level.to_string().to_lower()),
    "data": message,
  })
  self.out_channel.push!(notification)
}

///|
pub fn add_tool(
  self : Server,
  name~ : String,
  description~ : String,
  inputSchema~ : Schema,
  cb~ : async (Json, Server) -> Response
) -> Unit {
  self.tools[name] = Tool::{ description, inputSchema, cb }
  if self.running {
    @promise.spawn(async fn(_defer) {
      self.out_channel.push!(
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
      self.out_channel.push!(
        Notification(method_="notifications/tools/list_changed", params={}),
      )
    })
    |> ignore
  }
}

///|
pub fn add_prompt(
  self : Server,
  name~ : String,
  description~ : String,
  arguments~ : Array[PromptArgument] = [],
  cb~ : (Map[String, Json]) -> Array[PromptMessage]
) -> Unit {
  self.prompts[name] = Prompt::{ description, arguments, cb }
  if self.running {
    @promise.spawn(async fn(_defer) {
      self.out_channel.push!(
        Notification(method_="notifications/prompts/list_changed", params={}),
      )
    })
    |> ignore
  }
}

///|
pub fn remove_prompt(self : Server, name : String) -> Unit {
  self.prompts.remove(name)
  if self.running {
    @promise.spawn(async fn(_defer) {
      self.out_channel.push!(
        Notification(method_="notifications/prompts/list_changed", params={}),
      )
    })
    |> ignore
  }
}

///|
pub async fn list_roots(self : Server) -> Array[Root]! {
  if self.capabilities is { "roots": _, .. } && self.running {
    let channel = @channel.make(size=1)
    let lower = self.random.uint64().to_le_bytes()
    let higher = self.random.uint64().to_le_bytes()
    let random = FixedArray::make(16, b'\x00')
    random.blit_from_bytes(0, lower, 0, 8)
    random.blit_from_bytes(8, higher, 0, 8)
    let uuid = @uuid.from_bytes!(Bytes::from_fixedarray(random)).as_version(V4)
    let id = @rpc.String(uuid.to_string())
    self.callbacks[id] = channel
    self.out_channel.push!(Request(id~, method_="roots/list", params={}))
    let response = channel.pop!()
    self.callbacks.remove(id)
    guard response is Response(payload~, ..) else {
      fail!("Unexpected message for request roots/list: \{response}")
    }
    guard payload is Ok({ "roots": Array(roots), .. }) else {
      fail!("Unexpected payload for request roots/list")
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
