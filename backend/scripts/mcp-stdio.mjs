import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { ListToolsRequestSchema, CallToolRequestSchema, ListPromptsRequestSchema, GetPromptRequestSchema, ListResourcesRequestSchema, ReadResourceRequestSchema, ListResourceTemplatesRequestSchema } from '@modelcontextprotocol/sdk/types.js';

// For local clients that support stdio but cannot configure HTTP headers.
// Keep the token in the client's private environment, never in arguments/logs.
const token=process.env.KILO_MCP_TOKEN;
if(!token){console.error('KILO_MCP_TOKEN is required. Create a scoped token in the Web Agent settings.');process.exit(1);}
const remote=new Client({name:'kilo-stdio-bridge',version:'0.1.0'});
try {
  await remote.connect(new StreamableHTTPClientTransport(new URL(process.env.KILO_MCP_URL||'http://127.0.0.1:8791/mcp'),{requestInit:{headers:{authorization:`Bearer ${token}`}}}));
  const server=new Server({name:'kilo-member-agent',version:'0.1.0'},{capabilities:{tools:{},prompts:{},resources:{}}});
  server.setRequestHandler(ListToolsRequestSchema,(req)=>remote.listTools(req.params));
  server.setRequestHandler(CallToolRequestSchema,(req)=>remote.callTool(req.params));
  server.setRequestHandler(ListPromptsRequestSchema,(req)=>remote.listPrompts(req.params));
  server.setRequestHandler(GetPromptRequestSchema,(req)=>remote.getPrompt(req.params));
  server.setRequestHandler(ListResourcesRequestSchema,(req)=>remote.listResources(req.params));
  server.setRequestHandler(ReadResourceRequestSchema,(req)=>remote.readResource(req.params));
  server.setRequestHandler(ListResourceTemplatesRequestSchema,(req)=>remote.listResourceTemplates(req.params));
  await server.connect(new StdioServerTransport());
  const stop=async()=>{await server.close();await remote.close();process.exit(0);};
  process.on('SIGTERM',stop);process.on('SIGINT',stop);process.stdin.on('end',stop);
} catch {
  console.error('Unable to connect to KILO MCP. Check the Agent server, token expiry, membership and permissions.');process.exit(1);
}
