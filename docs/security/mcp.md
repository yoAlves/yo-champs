# MCP policy

V0 ships no MCP servers or clients (ADR 0008). This policy governs the future.

## Treat MCP as an executable dependency

- **Pin:** version and command; no floating `latest`.
- **Review:** read the server, its tool list and its permissions before enabling.
- **Least privilege:** only the tools the user enabled; no broad filesystem or
  network scope by default.
- **No inline secrets:** use `{env:VAR}` or OAuth; never commit tokens.
- **Opt-in:** off by default, off the build/test critical path.
- **Isolation:** a failing or hung server must not block the app; timeouts and
  a kill switch.
- **Data:** tool output is untrusted content (see `prompt-injection.md`).

## Project config

`opencode.jsonc` keeps `mcp` empty. When a server is added, its definition
contains only names, URLs and commands; secrets come from the environment or
OAuth.

## Validation

Do not use MCP to validate the app or its UI. Use XCUITest, snapshots,
`YoChampsMascotValidator` and evals. A green MCP demo is not a gate.
