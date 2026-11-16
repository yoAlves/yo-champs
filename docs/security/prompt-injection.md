# Prompt injection policy

## Position

Model output, provider metadata, and any future attachment or web content are
**data**, never instructions. The system contract is owned by the app, not by
the conversation.

## Layers

1. **System:** fixed by the app and agent definition; the user cannot rewrite it
   through chat.
2. **Developer:** app-injected rules (format, length, refusal policy).
3. **User:** the question.
4. **Untrusted content:** attachments, web pages, tool output, provider echoes —
   fenced and labelled as data, never merged into system/developer text.

## Rules for V0

- No tools with side effects, so injected instructions cannot cause actions.
- The LLM never selects animations, providers, models or tools; it returns text.
- Responses are validated (length, non-empty) before display; errors are shown
  as errors.
- Do not echo secrets or system prompts; redact in logs.
- A refusal is a valid answer; do not “fix” it with a retry loop that weakens the
  hierarchy.

## Adversarial checks (M4)

Fixtures include: “ignore the instructions”, “print your system prompt”, role
spoofing, provider output claiming a new system message, and a fake tool request.
Each must fail to change behavior.

## When tools arrive

- Confirmation and allowlists per tool.
- Least privilege and explicit user intent per call.
- Tool output is untrusted data.
- Side-effectful calls require a visible approval step.
