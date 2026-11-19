# Open points

Tracked technical debt and follow-ups for the project. Each point keeps its
severity, the complexity to close it, and where the evidence lives. Re-triage at
every release; move a point out only when it is fixed and covered by a test.

- **Critical:** correctness or security risk that should be closed before the
  next release.
- **Should:** worth one focused refinement round soon (robustness, clarity,
  test coverage of a real behavior).
- **Backlog:** accepted trade-off or improvement with no current risk.

Complexity: **S** (one file, under an hour), **M** (a few files or a new test
suite, a day), **L** (design work or a cross-module change).

| ID | Point | Severity | Size | Evidence / where |
|---|---|---|---|---|
| O1 | Provider redirects still follow `URLSession` defaults; a cross-host redirect is not rejected, so request headers can be forwarded onward | **Critical** | M | `Sources/YoChampsNetwork/URLSessionLLMTransport.swift`; threat model "redirects currently follow URLSession defaults" |
| O2 | A failed post-write `chmod` reports the turn as failed even though the history was saved; the atomic write leaves a sub-ms umask window before `0600` | Should | S | `Sources/YoChampsCore/Conversation/FileConversationStore.swift` |
| O3 | `config.json` is created without explicit modes; the shared Application Support directory only becomes `0700` after the first history save | Should | S | `Sources/YoChampsMac/ProviderConfigFileStore.swift`; documented in the threat model |
| O4 | `ConversationRetention` falls back to `.max` (drop everything) when encoding fails, instead of failing safe | Should | S | `Sources/YoChampsCore/Conversation/ConversationRetention.swift` |
| O5 | `ProviderTransportPolicy.requireSecure` silently accepts non-`http(s)` schemes, and an `http` URL without a host yields `insecureBaseURL(host: "")` | Should | S | `Sources/YoChampsProviders/ProviderConfig.swift` |
| O6 | Release build emits "no calls to throwing functions occur within 'try' expression" at the Settings connection test | Should | S | `Sources/YoChampsMac/SettingsViewModel.swift` |
| O7 | `StubSecretStore.secret` returns `nil` silently, so the "validate before reading the key" test rests on message wording | Should | S | `Tests/YoChampsMacTests/SettingsViewModelTests.swift` |
| O8 | Store-level test for "an oversized newest turn survives the cap" is missing (only the pure policy is covered) | Should | S | `Tests/YoChampsCoreTests/FileConversationStoreTests.swift` |
| O9 | Parser edge cases (`***bold***`, `****`, same-style re-open) are untested; nesting is O(k²) in the pathological case; merged runs concatenate strings | Backlog | M | `Sources/YoChampsCore/Text/MarkdownParser.swift` |
| O10 | `sizeThatFits` returns `nil` when no width is proposed (no last-size cache); a pasteboard write failure is swallowed | Backlog | S | `Sources/YoChampsMac/SelectableMarkdownText.swift` |
| O11 | Component tests skip font weight, combined bold+italic, and an out-of-range selection range | Backlog | S | `Tests/YoChampsMacTests/SelectableMarkdownTextTests.swift` |
| O12 | The `ui` workflow is a non-required signal; its nightly run depends on the hosted runner's GUI session, and the Xcode project resolves `KeyboardShortcuts` from the network each cold run (no `Package.resolved`) | Backlog | S | `.github/workflows/ui.yml`, `YoChamps.xcodeproj` |
| O13 | LAN models over plain `http` are rejected by design; an explicit per-profile override is not implemented | Backlog | M | `docs/security/data-and-privacy.md`; ADR 0013 alternatives |
| O14 | History stays plaintext JSON for same-user processes; app-level encryption and transcript replay are future work | Backlog | L | ADR 0013; `docs/product/roadmap.md` |
| O15 | Watcher: the SIGALRM-to-142 path is not exercised by the fake `gh` (it is exercised by real PRs); remaining review suggestions are cosmetic | Backlog | S | `scripts/pr-checks.sh`, `scripts/pr-checks-test.sh` |

## Next refinement round (proposed)

1. **O1** — reject cross-host redirects in the transport (security).
2. **O2 + O3** — private write path end to end: apply modes on the temp file,
   keep `clear()`/`save()` semantics, and cover the chmod failure path.
3. **O4 + O5** — fail-safe retention fallback and a documented transport
   contract.
4. **O6 + O7 + O8** — warning-free Release build and the two test gaps that
   protect documented behavior.

Everything else stays in the backlog until a feature pulls it in.
