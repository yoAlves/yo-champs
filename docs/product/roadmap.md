# Roadmap (post-V0)

The V0 contract is frozen in `v0.md`. This is directional, not a commitment.

- **Post-0.1.0 hardening (M4 backlog):** evals, injection fixtures,
  performance report, `make release-dry-run`, recorded demo.
- **V0.1:** slash commands, model picker, copy/retry actions. The chat-panel
  restyle, new-chat shortcut, Markdown answers and copy-on-select already shipped
  (2026-11-19 hardening).
- **V0.2:** translation/English presets, more asset packs.
- **V1:** attachments/OCR (Vision), transcription (Speech/whisper.cpp), calendar
  (EventKit), web search tool, MCP client.
- **V1.5:** local models (MLX/Ollama), RAG/memory (GRDB, later tantivy/lancedb),
  history search, visible transcript replay in the Ask window (stored history is
  already sent as context), optional app-level encryption for local history.
- **V2:** multi-OS (Tauri or native shells over a daemon), agent/plugin SDK,
  pack marketplace, auto-update, Homebrew, OpenCode runtime adapter, MCP server
  mode (expose the companion).

Rules that still apply: editions/channels are configuration (no forks),
capabilities gate UI, schemas are versioned, and every new surface gets a gate.
