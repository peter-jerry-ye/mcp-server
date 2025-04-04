# MCP Server SDK

A WIP MoonBit implementation to support [Model Context Protocol](https://modelcontextprotocol.io/) based on Wasm's Component Model.

The user can use this to develop a running MCP server, providing more functionality to their AI models, while feeling confident as the Wasm is sandboxed.

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

See `./example` for a simple weather MCP server.

## TODO

- Add documentation
- Add tests
- Support more features
- Better error handling and better UX