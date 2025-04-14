///|
fn main {
  try {
    let uv = @uv.Loop::new!()
    let out = @uv.Pipe::new!(uv, ipc=true)
    let err = @uv.Pipe::new!(uv, ipc=true)
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
    @promise.spawn(async fn(_defer) {
      let reader = out.to_stream()
        |> stream
        |> @stream.input_stream_reader
        |> @stream.buffered_reader
      let writer = file(@uv.stdin(), uv) |> @stream.output_stream_writer
      try {
        while true {
          let line = reader.read_line().await!!()
          writer.write("\{line}\n").await!!()
        }
      } catch {
        @uv.EOF => {
          writer.close()
          reader.close()
          err.close(ignore)
        }
        e => println("Error reading from stream: \{e}")
      }
    })
    |> ignore
    uv.run!(Default)
    uv.close!()
  } catch {
    e => println("Error occurred: \{e}")
  }
}
