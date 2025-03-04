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
  let server = @mcp.new()
  server.add_tool(
    name="get_weather",
    description=
      #|Get current weather information for a city from wttr.in.
      #|The city name (in English) is passed as an argument.
    ,
    inputSchema=@mcp.object({ "location": @mcp.string() }, required=["location"]),
    cb=async fn(args, server) {
      guard args is { "location": String(city), .. }
      let weather = @http.fetch(
        @http.request!(
          "wttr.in",
          path="/" + city.replace_all(old=" ", new="%20") + "?format=4",
        ),
      ).await!!()
      server.log!!("Got weather response")
      server.log!!("Roots: \{server.list_roots!!()}")
      @mcp.Response::{
        isError: weather.status() != 200,
        payload: Text(
          text=if weather.status() == 200 {
            @http.text(weather.consume().unwrap()).0.await!!()
          } else {
            "Failed to fetch weather data: \{@http.text(weather.consume().unwrap()).0.await!!()}"
          },
        ),
      }
    },
  )
  server.serve()
}
