///|
fn main {
  try {
    let uv = @uv.Loop::new!()
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
        @uv.StdioContainer::inherit_file(@uv.stdout()),
        @uv.StdioContainer::inherit_file(@uv.stderr()),
      ],
    )
    uv.spawn!(options) |> ignore
    uv.run!(Default)
    uv.close!()
  } catch {
    _ => panic()
  }
}
