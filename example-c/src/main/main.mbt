///|
fn main {
  try {
    let uv = @uv.Loop::new!()
    @promise.spawn(async fn(_defer) {
      let random = random!!(uv, 32)
      let server = @mcp.new(random)
      server.add_tool(
        name="moon version",
        description="get the version of moonbit tool",
        inputSchema=@schema.object({}),
        cb=async fn(_json, _server) {
          try {
            let out = @uv.Pipe::new!(uv)
            let err = @uv.Pipe::new!(uv)
            let options = @uv.ProcessOptions::new(
              "moon",
              ["moon", "version", "--all"],
              fn(process, exit_status, term_signal) {
                println(
                  "Process exited with status \{exit_status} and signal \{term_signal}.",
                )
                process.close(ignore)
              },
              stdio=[
                @uv.StdioContainer::ignore(),
                @uv.StdioContainer::create_pipe(
                  out.to_stream(),
                  writable=true,
                  non_block=true,
                ),
                @uv.StdioContainer::create_pipe(
                  err.to_stream(),
                  writable=true,
                  non_block=true,
                ),
              ],
            )
            uv.spawn!(options) |> ignore
            let reader = out.to_stream()
              |> stream
              |> @stream.input_stream_reader
              |> @stream.buffered_reader
            let buffer = StringBuilder::new()
            // TODO: stderr
            try {
              while true {
                let line = reader.read_line().await!!()
                buffer..write_string(line).write_char('\n')
              }
              panic()
            } catch {
              @uv.Errno(EOF) => {
                reader.close()
                err.close(ignore)
                @mcp.Response::{
                  isError: false,
                  payload: [@mcp.Text(text=buffer.to_string())],
                }
              }
              e => raise e
            }
          } catch {
            e =>
              @mcp.Response::{
                isError: true,
                payload: [@mcp.Text(text=e.to_string())],
              }
          }
        },
      )
      server.serve(
        stdin=@stream.input_stream_reader(file(@uv.stdin(), uv)),
        stdout=@stream.output_stream_writer(file(@uv.stdout(), uv)),
        stderr=@stream.output_stream_writer(file(@uv.stderr(), uv)),
      )
    })
    |> ignore
    uv.run!(Default)
    uv.close!()
  } catch {
    e => println("Error occurred: \{e}")
  }
}
