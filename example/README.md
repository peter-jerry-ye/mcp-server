# MCP Example

This project uses MoonBit to develop a MCP Server, and uses TypeScript to develop a MCP Client to validate against it.

## Develop

For TypeScript, you need [`deno`](https://deno.com/).

For building script, you need [`just`](https://just.systems/)

Running `just test`, you should see that the client has connected to the MCP server, logging messages (including the roots), and get a weather result from [wttr.in](https://github.com/chubin/wttr.in).

## Usage

For Cline, you may have a configuration like this:

```json
{
  "mcpServers": {
    "weather": {
      "command": "wasmtime",
      "args": [ "-S", "http=y", "path/to/target/cli.wasm" ],
      "disabled": false,
      "autoApprove": []
    }
  }
}
```