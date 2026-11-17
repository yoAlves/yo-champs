# Ask Panel Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Todo summon do painel (hotkey/demo/primeira abertura) deixa o cursor no campo "Ask Champ…", sem clique.

**Architecture:** `AskPanelController.show()` incrementa um token de visibilidade num pequeno `ObservableObject` (`PanelState`); `AskView` observa o token e seta `isFocused = true` via `.onChange`. O `.onAppear` atual permanece para a primeira aparição. Token (contador) em vez de flag booleana evita o caso "estado preso em `true`" (fechar pelo botão vermelho não passa por `hide()`).

**Tech Stack:** Swift 6 / SwiftUI / AppKit, macOS 14+ (onChange de dois parâmetros disponível).

**Spec:** `docs/superpowers/specs/2026-11-17-ask-panel-focus-design.md`

## Global Constraints

- Deps: nenhuma nova; mudança restrita a `Sources/YoChampsMac` (AskPanel.swift, AskView.swift).
- Core (`YoChampsCore`) não é tocado; nenhuma dependência reversa.
- Gate obrigatório antes de considerar pronto: `make verify` (lint, test, build, pack, secrets) — colar comando e saída.
- Sem teste unitário para o foco: `@FocusState` de SwiftUI não é testável no alvo Mac hoje (XCUITest chega em M1+, ADR 0002). Verificação é build + checagem manual.

## Review Focus

1. **Reabrir após fechar pelo botão vermelho da janela** — caminho que não passa por `hide()`; esperado: cursor foca mesmo assim (por isso token incremental, não flag). Pin: checagem manual no passo 7.
2. **Abrir durante stream (`isBusy`)** — campo `.disabled`; esperado: sem foco (fora de escopo por design). Pin: mencionado na checagem manual, não corrige.
3. **Primeira abertura** — `onAppear` existente continua cobrindo; token incrementa também, inofensivo. Pin: checagem manual no passo 7.
4. **Esc / toggle hide → reabrir** — token muda a cada `show()`, onChange dispara de novo. Pin: checagem manual no passo 7.

---

### Task 1: Foco a cada `show()`

**Files:**
- Modify: `Sources/YoChampsMac/AskPanel.swift` (adicionar `PanelState` perto do topo, entre `AskPanel` e `PanelCloseHandler`; wiring em `AskPanelController`)
- Modify: `Sources/YoChampsMac/AskView.swift` (propriedade + `onChange`; linhas 3-10 e após `.onAppear`/`.onExitCommand`, ~linha 86)

**Interfaces:**
- Consumes: nada novo.
- Produces: `@MainActor final class PanelState: ObservableObject` com `@Published var showToken: Int` (usado por `AskPanelController` e `AskView`).

- [ ] **Step 1: Implementar `PanelState` em `Sources/YoChampsMac/AskPanel.swift`**

```swift
/// Carried by the panel controller into `AskView`; each `show()` bumps the
/// token so the view can re-focus the field. A counter, not a flag: the red
/// close button bypasses `hide()`, so a boolean could stay `true`.
@MainActor
final class PanelState: ObservableObject {
    @Published var showToken = 0
}
```

- [ ] **Step 2: Wire `AskPanelController`**

- Nova propriedade: `private let panelState = PanelState()`.
- `init`: `NSHostingView(rootView: AskView(model: model, onClose: hidePanel, renderer: renderer, panelState: panelState))`.
- `show()`: após `panel.makeKeyAndOrderFront(nil)`, adicionar `panelState.showToken += 1`.

- [ ] **Step 3: Reagir em `AskView.swift`**

- Nova propriedade: `@ObservedObject var panelState: PanelState` (após `renderer`).
- Após `.onExitCommand(perform: onClose)`:

```swift
.onChange(of: panelState.showToken) { _, _ in
    isFocused = true
}
```

- [ ] **Step 4: Build**

Run: `make build`
Expected: exit 0.

- [ ] **Step 5: Gate**

Run: `make verify`
Expected: exit 0 (lint + testes + build + pack + secrets). Colar saída.

- [ ] **Step 6: Checagem manual (usuário)**

Run: `make run`. Summon pelo hotkey **duas vezes seguidas**, fechar pelo botão vermelho e reabrir. Esperado: cursor no campo "Ask Champ…" em todas as aberturas. Abrir durante um stream: campo desabilitado, sem foco (comportamento aceito).

- [ ] **Step 7: Commit** (só mediante pedido explícito do usuário)

```bash
git checkout -b fix/ask-panel-focus
git add Sources/YoChampsMac/AskPanel.swift Sources/YoChampsMac/AskView.swift docs/superpowers/specs/2026-11-17-ask-panel-focus-design.md docs/superpowers/plans/2026-11-17-ask-panel-focus.md
git commit -m "fix: focus Ask Champ field on every panel show"
```

---

### Task 2: Foco na primeira abertura (app inativo no summon)

Report do usuário: primeira abertura não foca; clicar no campo, fechar e
reabrir foca. Causa raiz: o app é `.accessory` e está **inativo** no
primeiro summon — `activate()` completa um instante depois de `show()`, e
`makeKeyAndOrderFront` num app inativo não torna a janela key na hora. O
bump do token e o `onAppear` disparam antes; `@FocusState` numa janela
que ainda não é key é no-op. No teste que funcionou, o clique no campo
ativou o app, então a reabertura tinha janela key imediata.

**Files:**
- Modify: `Sources/YoChampsMac/AskPanel.swift` (`AskPanel.onBecomeKey` + override `becomeKey`; wiring no controller)

**Interfaces:**
- Consumes: `PanelState.showToken` (Task 1).
- Produces: `AskPanel.onBecomeKey: (() -> Void)?`.

- [ ] **Step 1: `AskPanel`bumpe o token quando virar key**

`override func becomeKey() { super.becomeKey(); onBecomeKey?() }` com
`var onBecomeKey: (() -> Void)?`; o controller seta
`panel.onBecomeKey = { [weak self] in self?.panelState.showToken += 1 }`.
O bump em `show()` permanece (cobre re-show com janela já key; duplicado é inofensivo).

- [ ] **Step 2: Build + gate**

Run: `make build && make verify` — Expected: exit 0.

- [ ] **Step 3: Checagem manual (usuário)** — primeira abertura pós-launch com cursor no campo.

- [ ] **Step 4: Commit** (só mediante pedido explícito do usuário)

---

### Task 3: Painel ativo a cada invocação (hotkey)

Report do usuário (com print): painel aparece na frente mas **inativo**
(titlebar acinzentada) quando invocado pela hotkey com outro app em
primeiro plano; precisa clicar pra ativar. Causa raiz: app `.accessory`
inativo; `activate()` simples é recusado pela prevenção de roubo de foco
do macOS moderno → janela nunca vira key → `becomeKey` (fix da Task 2)
não tem gatilho. Spec: `docs/superpowers/specs/2026-11-17-panel-activation-design.md`.

**Files:**
- Modify: `Sources/YoChampsMac/AskPanel.swift` (show() + observer de didBecomeActive + `raisePanelIfVisible()` + deinit)

**Interfaces:**
- Consumes: `AskPanel.onBecomeKey` → bump do token (Task 2) — inalterado.
- Produces: nada novo para outras tasks.

- [ ] **Step 1: Forçar ativação em `show()`**

`NSApplication.shared.activate(ignoringOtherApps: true)` no lugar de
`activate()` (deprecated no macOS 14+, warning benigno aceito).

- [ ] **Step 2: Re-ordenar quando a ativação completar**

Observer de `didBecomeActiveNotification` (block-based, `queue: .main`,
`MainActor.assumeIsolated`, observer guardado em
`activationObserver: (any NSObjectProtocol)?` e removido no `deinit`);
`raisePanelIfVisible()`: se `panel.isVisible && !panel.isKeyWindow`,
`panel.makeKeyAndOrderFront(nil)`.

- [ ] **Step 3: Build + gate**

Run: `make build && make verify` — Expected: exit 0.

- [ ] **Step 4: Checagem manual (usuário)** — hotkey com terminal/browser em primeiro plano: painel ativo, cursor no campo, sem clique. Cenário extra (S1 da review): com o painel Ask visível e não-key, abrir Settings pelo menu — o campo Ask não deve roubar a digitação da janela de Settings.

- [ ] **Step 5: Commit** (só mediante pedido explícito do usuário)
