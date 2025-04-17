///|
fn main {
  try {
    let uv = @uv.Loop::new!()
    @promise.spawn(async fn(_defer) {
      let random = random!(uv, 32)
      let server = @mcp.new(random)
      server.add_tool(
        name="moon version",
        description="get the version of moonbit tool",
        inputSchema=@schema.object({}),
        cb=async fn(_json, _server) {
          try {
            server.log!("Getting the version of moonbit toolchain", level=Debug)
            let process = spawn!(uv, "moon", args=["version", "--all"])
            server.log!("Executing command", level=Debug)
            if process.exit_status.await!() == 0 {
              @mcp.Response::{
                isError: false,
                payload: [@mcp.Text(text=process.stdout.await!())],
              }
            } else {
              @mcp.Response::{
                isError: true,
                payload: [@mcp.Text(text=process.stderr.await!())],
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
      server.add_tool(
        name="moon check",
        description=
          #|perform a check in the code base. 
          #|
          #|Two parameters are required: 
          #|The first parameter is the path to the codebase.
          #|The second parameter is the backend to be checked on. Currently there's only `wasm-gc` `wasm` `native` and `js`.
        ,
        inputSchema=@schema.object(
          {
            "path": @schema.string(),
            "backend": @schema.enums(["wasm-gc", "wasm", "native", "js"]),
          },
          required=["path", "backend"],
        ),
        cb=async fn(params, _server) {
          guard params
            is { "path": String(path), "backend": String(backend), .. }
          try {
            let process = spawn!(uv, "moon", args=[
              "check", "-C", path, "--target", backend,
            ])
            if process.exit_status.await!() == 0 {
              @mcp.Response::{
                isError: false,
                payload: [@mcp.Text(text=process.stdout.await!())],
              }
            } else {
              @mcp.Response::{
                isError: true,
                payload: [@mcp.Text(text=process.stderr.await!())],
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
struct ChildProcess {
  pid : Int
  stdout : @promise.T[String]
  stderr : @promise.T[String]
  exit_status : @promise.T[Int64]
}

///|
fn spawn(
  uv : @uv.Loop,
  command : String,
  args~ : Array[String] = []
) -> ChildProcess! {
  let out = @uv.Pipe::new!(uv)
  let err = try {
    @uv.Pipe::new!(uv)
  } catch {
    e => {
      out.close(ignore)
      raise e
    }
  }
  let exit_status = @promise.make()
  let options = @uv.ProcessOptions::new(
    command,
    [command, ..args],
    fn(process, status, _term_signal) {
      exit_status.resolve(status)
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
  let pid = try {
    uv.spawn!(options).pid()
  } catch {
    e => {
      out.close(ignore)
      err.close(ignore)
      raise e
    }
  }
  let stdout = @promise.spawn(async fn(_defer) {
    collect_output!(out.to_stream() |> stream)
  })
  let stderr = @promise.spawn(async fn(_defer) {
    collect_output!(err.to_stream() |> stream)
  })
  { exit_status: exit_status.future(), stdout, stderr, pid }
}

///|
async fn collect_output[T : @stream.InputStream](stream : T) -> String! {
  let buffer = StringBuilder::new()
  let reader = stream |> @stream.input_stream_reader |> @stream.buffered_reader
  try {
    while true {
      let line = reader.read_line().await!()
      buffer..write_string(line).write_char('\n')
    }
    panic()
  } catch {
    @uv.Errno(EOF) => buffer.to_string()
    e => raise e
  }
}
