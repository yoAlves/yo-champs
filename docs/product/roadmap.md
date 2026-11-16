# Roadmap (post-V0)

The V0 contract is frozen in `v0.md`. This is directional, not a commitment.

- **V0.1:** slash commands, model picker, copy/retry, settings polish.
- **V0.2:** translation/English presets, markdown in streaming, more asset packs.
- **V1:** attachments/OCR (Vision), transcription (Speech/whisper.cpp), calendar
  (EventKit), web search tool, MCP client.
- **V1.5:** local models (MLX/Ollama), RAG/memory (GRDB, later tantivy/lancedb),
  history search.
- **V2:** multi-OS (Tauri or native shells over a daemon), agent/plugin SDK,
  pack marketplace, auto-update, Homebrew, OpenCode runtime adapter, MCP server
  mode (expose the companion).

Rules that still apply: editions/channels are configuration (no forks),
capabilities gate UI, schemas are versioned, and every new surface gets a gate.
