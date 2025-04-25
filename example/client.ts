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

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { ListRootsRequestSchema, ListRootsResult, LoggingMessageNotificationSchema } from "@modelcontextprotocol/sdk/types.js";

const transport = new StdioClientTransport({
    command: "wasmtime",
    args: ["-S", "http=y", "./target/cli.wasm"],
    env: { "PATH": Deno.env.get("PATH") ?? "" }
})

const client = new Client({ name: "example-client", version: "0.1.0" }, {
    capabilities: {
        roots: {}
    }
});

client.setRequestHandler(ListRootsRequestSchema, (): ListRootsResult => {
    return {
        "roots": [{
            "uri": "file:///home/user/projects/myproject"
        }, {
            "uri": "file:///home/user/projects/anotherproject"
        }]
    };
})


client.setNotificationHandler(LoggingMessageNotificationSchema, ({
    params: {
        level, logger, data
    }
}) => {
    switch (level) {
        case "debug": console.trace(logger, data); break;
        case "info": console.info(logger, data); break;
        case "warning":
        case "alert":
        case "emergency":
        case "critical": console.warn(logger, data); break;
        case "error": console.error(logger, data); break;
    }
})

await client.connect(transport);

client.setLoggingLevel("info")

const { tools } = await client.listTools();

console.log("Connected to MCP Server. Available tools: ", tools.map((v) => v.name));

const { resources } = await client.listResources();

console.log("Connected to MCP Server. Available resources: ", resources.map((v) => v.name));

const { prompts } = await client.listPrompts();

console.log("Connected to MCP Server. Available prompts: ", prompts.map((v) => v.name));

const { resourceTemplates } = await client.listResourceTemplates();

console.log("Connected to MCP Server. Available templates: ", resourceTemplates.map((v) => v.name));

const result = await client.callTool({
    "name": "get_weather",
    "arguments": {
        "location": "New York"
    }
})

console.log("Called MCP Server. Result: ", result)

client.close();