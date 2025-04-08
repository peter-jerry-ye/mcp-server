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

///| Run the program.
/// 
/// This function handles the initialization step of MCP Server
/// and the consequent messages' i/o.
pub fn run() -> Result[Unit, Unit] {
  // read from stdin for input channel
  let in_channel : @channel.T[@rpc.Message] = @channel.make(size=10)
  @promise.spawn(async fn(_defer) {
    while true {
      try {
        let message = @io.read_line!!() |> @json.parse!() |> @json.from_json!()
        in_channel.push!!(message)
      } catch {
        @streams.Closed => break
        e => {
          @io.println!!(e.to_string(), stream=@io.stderr)
          break
        }
      }
    }
  })
  |> ignore
  let out_channel : @channel.T[@rpc.Message] = @channel.make(size=10)
  // write to stdout for output channel
  @promise.spawn(async fn(_defer) {
    while true {
      let message = out_channel.pop!!()
      @io.println!!(message.to_json() |> @json.stringify)
    }
  })
  |> ignore
  let server = @mcp.new(in_channel, out_channel, Bytes::from_fixedarray(@random.get_random_bytes(32)))
  server.add_tool(
    name="get_weather",
    description=
      #|Get current weather information for a city from wttr.in.
      #|The city name (in English) is passed as an argument.
    ,
    inputSchema=@schema.object({ "location": @schema.string() }, required=[
      "location",
    ]),
    cb=async fn(args, server) {
      try {
        guard args is { "location": String(city), .. }
        let weather = @http.fetch!!(
          @http.request!(
            "wttr.in",
            path="/" + city.replace_all(old=" ", new="%20") + "?format=4",
          ),
        )
        server.log!!("Got weather response")
        server.log!!("Roots: \{server.list_roots!!()}")
        @mcp.Response::{
          isError: weather.status() != 200,
          payload: [
            Text(
              text=if weather.status() == 200 {
                @http.text(weather.consume().unwrap()).0.await!!()
              } else {
                "Failed to fetch weather data: \{@http.text(weather.consume().unwrap()).0.await!!()}"
              },
            ),
          ],
        }
      } catch {
        error =>
          @mcp.Response::{
            isError: true,
            payload: [Text(text="Failed to fetch weather data: \{error}")],
          }
      }
    },
  )
  server.add_prompt(
    name="get weather",
    description="instruct the AI to get weather for a city",
    arguments=[@mcp.prompt_argument("city")],
    cb=fn {
      { "city"? : city, .. } => {
        let city = city.or("Beijing")
        [{ role: User, message: Text(text="Get weather for \{city}") }]
      }
    },
  )
  @promise.spawn(async fn(_defer) { server.serve!!() }) |> ignore
  @io.event_loop.run()
  Ok(())
}
