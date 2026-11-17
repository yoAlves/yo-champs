# Design: foco no campo "Ask Champ…" a cada abertura do painel

Data: 2026-11-17 · Escopo: pequeno (2 arquivos, ~15 linhas)

## Intent e o porquê

Hoje o cursor só cai no campo "Ask Champ…" na **primeira** abertura do
painel. Nas demais, o usuário precisa clicar no campo antes de digitar.
O esperado é: todo summon do companion (hotkey, demo, primeira abertura)
deixa o cursor já no campo, pronto para digitar.

## Causa raiz

- `AskView` seta `isFocused = true` em `.onAppear` (AskView.swift:83-85).
- `AskPanel` é criado uma vez em `AskPanelController.init` e reutilizado:
  `hide()` faz `orderOut`, `show()` faz `makeKeyAndOrderFront` — a view
  SwiftUI nunca "re-aparece", então `onAppear` não dispara de novo.

## Abordagens consideradas

1. **Sinal do controller para a view (escolhida)** — `show()` sinaliza a
   visibilidade; `AskView` reage e seta `isFocused = true`. Mantém o
   `@FocusState` na view, cobre todas as aberturas, mudança mínima.
2. **Forçar re-appear** — recriar a view a cada `show()` (`.id` novo ou
   reatribuir `contentView`). Funciona, mas descarta estado visual à
   toa e é mais frágil. Descartada.

## Como será implementado (abordagem 1)

- `AskPanelController` publica a visibilidade do painel (pequeno
  observável, ex. `@Published var isPanelVisible` num estado mínino ou
  propriedade do controller exposta como observável).
- `AskView` recebe esse sinal e usa `.onChange`/`.onReceive` para setar
  `isFocused = true` sempre que o painel ficar visível; o `.onAppear`
  atual permanece para a primeira abertura.
- `hide()` atualiza o mesmo sinal para `false`.

  > Revisão pós-implementação (2026-11-17): o sinal é um **token
  > monotônico** (`showToken`), incrementado só em `show()`; `hide()` não
  > o toca. Um booleano podia ficar preso em `true` no caminho do botão
  > vermelho da janela, que não passa por `hide()`. O plano aprovado
  > (`docs/superpowers/plans/2026-11-17-ask-panel-focus.md`) é a fonte
  > operativa.

## Goals

- Cursor no campo a cada `show()`/`toggle()` que abre o painel.

## Non-goals / anti-goals

- Não tratar foco durante stream (`isBusy`): o campo fica `.disabled`,
  foco nele é no-op; quando o stream termina o campo reabilita, mas não
  há auto-foco — comportamento aceito por ora. Se incomodar depois,
  vira melhoria própria.
- Nenhuma mudança no Core, no view model de streaming ou no
  posicionamento do painel (placement/translucência são M3).

## O que fica para o builder

- Detalhe mecânico do canal de sinal (observável dedicado vs.
  `NotificationCenter`): a seu critério, preferindo o mais simples e
  testável dentro de `Sources/YoChampsMac`.
