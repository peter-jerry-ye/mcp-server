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
            let process = @promise.spawn(async fn(_defer) {
              shift!!(fn(resolve, reject) {
                let options = @uv.ProcessOptions::new(
                  "moon",
                  ["moon", "version", "--all"],
                  fn(process, exit_status, _term_signal) {
                    resolve(exit_status)
                    out.close(ignore)
                    err.close(ignore)
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
                match uv.spawn?(options) {
                  Err(e) => reject(e)
                  Ok(_) => ()
                }
              })
            })
            let stdout = @promise.spawn(async fn(_defer) {
              collect_output!!(out.to_stream() |> stream)
            })
            let stderr = @promise.spawn(async fn(_defer) {
              collect_output!!(err.to_stream() |> stream)
            })
            let exit_status = process.await!!()
            if exit_status == 0 {
              @mcp.Response::{
                isError: false,
                payload: [@mcp.Text(text=stdout.await!!())],
              }
            } else {
              @mcp.Response::{
                isError: true,
                payload: [@mcp.Text(text=stderr.await!!())],
              }
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

///|
async fn collect_output[T : @stream.InputStream](stream : T) -> String! {
  let buffer = StringBuilder::new()
  let reader = stream |> @stream.input_stream_reader |> @stream.buffered_reader
  try {
    while true {
      let line = reader.read_line().await!!()
      buffer..write_string(line).write_char('\n')
    }
    panic()
  } catch {
    @uv.Errno(EOF) => buffer.to_string()
    e => raise e
  }
}
