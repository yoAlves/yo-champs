# ADR 0003 — Provider-agnostic OpenAI-compatible contract

**Status:** accepted (2026-11-15).
**Covers:** D03, D08, D17, D21.

## Context

The app must work with OpenAI, OpenRouter, Ollama, LM Studio and OpenCode Go
without recompiling or knowing vendor names. V0 needs one generalist agent.

## Decision

- Core knows only `ProviderProfile` and `LLMProvider`; `kind` is
  `openai-compatible` in V0.
- Base URL, model, headers and capabilities are data. No provider/model name in
  Core.
- No real provider is a default; without a profile, onboarding runs. The mock
  provider serves demo/tests.
- One generalist agent behind an `AgentRegistry`.
- OpenCode Go is a personal profile with an intended-use notice (coding agent),
  not a public default. The OpenCode runtime is a future `AgentBackend`, separate
  from the provider.

## Consequences

- Providers can be added as JSON profiles and (eventually) new adapters.
- Slash commands and UI filter by declared capabilities.
- Vendor-specific features need capability flags, not Core branching.
