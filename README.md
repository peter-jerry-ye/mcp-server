# MCP Server SDK

A WIP MoonBit implementation to support [Model Context Protocol](https://modelcontextprotocol.io/).

Supported backends:

- Wasm's Component Model
- Native backend

and more (as long as an implementation exists for `peter-jerry-ye/async/stream`).

The user can use this to develop a running MCP server, providing more functionality to their AI models.

## Currently Supported Features

Version:
- 2024-11-05

Transport:
- Stdio

Provide server capabilities:
- Tools
- Prompts

Call client capabilities (if provided):
- List roots

## Example

See `./example` for a simple weather MCP server in Wasm, and `./example-c` for a simple MCP server in native backend.

## TODO

- Add documentation
- Add tests
- Support more features
- Better error handling and better UX