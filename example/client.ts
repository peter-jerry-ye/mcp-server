import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { ListRootsResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

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

client.setRequestHandler(z.object({
    method: z.literal("roots/list")
}), () => {
    return ({
        "roots": [{
            "uri": "file:///home/user/projects/myproject"
        }, {
            "uri": "file:///home/user/projects/anotherproject"
        }]
    } as ListRootsResult);
})


client.setNotificationHandler(z.object({
    method: z.literal("notifications/message"), params: z.object({
        level: z.string(),
        logger: z.optional(z.string()),
        data: z.any()
    })
}), ({
    params: {
        level, logger, data
    }
}) => {
    switch (level) {
        case "info": console.info(logger, data); break;
        case "debug": console.trace(logger, data); break;
        case "warning":
        case "alert":
        case "emergency":
        case "critical": console.warn(logger, data); break;
        case "error": console.error(logger, data); break;
    }
})

await client.connect(transport);

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