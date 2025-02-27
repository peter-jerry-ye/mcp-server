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
      guard let { "location": String(city), .. } = args
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
