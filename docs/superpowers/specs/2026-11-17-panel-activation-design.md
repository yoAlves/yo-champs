# Design: painel do companion ativo a cada invocação (hotkey)

Data: 2026-11-17 · Escopo: pequeno (AskPanel.swift, ~10 linhas)

## Intent e o porquê

Invocado pela hotkey com outro app em primeiro plano, o painel aparece
na frente mas **inativo** (titlebar acinzentada, sem key): o usuário
precisa clicar nele pra digitar. Esperado: summon deixa o painel ativo
e o cursor no campo, sem clique.

## Causa raiz

O app é `.accessory`/LSUIElement e está inativo no summon.
`NSApplication.shared.activate()` chamado em `show()` é recusado/atrasado
pela prevenção de roubo de foco do macOS moderno; sem ativação a janela
nunca vira key → `becomeKey` não dispara → o foco (fix anterior) não tem
gatilho e a janela fica inativa até o clique.

## Abordagens

1. **Forçar ativação + re-ordenar na ativação (escolhida)** —
   `activate(ignoringOtherApps: true)` no `show()` (deprecated no macOS
   14+, mas é o caminho funcional usado por apps de menu bar; warning
   benigno) e, cobrindo o "a ativação chega um beat depois",
   `NSApplication.didBecomeActiveNotification` → se o painel estiver
   visível e não key, `makeKeyAndOrderFront`. O bump em `becomeKey`
   (fix anterior) dá o foco quando a janela virar key.
2. **Só `orderFrontRegardless()`** — traz pra frente sem ativar; janela
   segue sem key, foco não pega. Não resolve o sintoma. Descartada.
3. **Política `.regular`** — foco fácil, mas quebra a natureza de menu
   bar companion (LSUIElement, decisão de design do M0). Descartada.

## Como será implementado (abordagem 1)

- `show()`: trocar `NSApplication.shared.activate()` por
  `NSApplication.shared.activate(ignoringOtherApps: true)`.
- `AskPanelController` observa `didBecomeActiveNotification` (sink
  guardado em propriedade, `@MainActor`); no disparo, se
  `panel.isVisible && !panel.isKeyWindow`, chama
  `panel.makeKeyAndOrderFront(nil)`.
- Resto inalterado: `becomeKey` → bump do token → foco no campo.

## Goals

- Summon por hotkey (e menu/URL/demo) deixa o painel ativo, key, com
  cursor no campo, sem clique.

## Non-goals / anti-goals

- Não muda política de ativação do app nem o chrome/posição do painel.
- Não guarda contra "roubo" de foco além do summon (re-key espontâneo
  permanece conforme decisão anterior).

## O que fica para o builder

- Detalhe do sink de notificação (publisher vs. selector): a seu
  critério, seguindo padrões do arquivo. Verificação continua manual
  (ativação de janela não é testável sem XCUITest, M1+).
