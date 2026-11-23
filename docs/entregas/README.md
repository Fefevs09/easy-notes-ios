# Índice Consolidado das Entregas — Easy Notes (macOS)

Este documento consolida objetivos, decisões arquiteturais, contratos entre módulos, validações no Xcode, ordem de integração e pendências das quatro entregas coordenadas pela equipe multiagente no T3 Code, permitindo que qualquer thread futura retome o trabalho sem depender do histórico da conversa.

---

## 1. Resumo Executivo e Base Git

- **Base remota no início da coordenação:** `origin/main` em `e522bd6`.
- **Base local incorporada na preparação:** `main` em `7c187c7` (adicionou o seletor horizontal de cor da caneta em `PenColorPickerView.swift`). O PR #2 inclui `7c187c7` como dependência acima de `origin/main`.
- **Infraestrutura compartilhada (`f269874` / PR #2):** habilitou o target `EasyNotesTests` no projeto Xcode, compartilhou o esquema `Easy Notes` e estabilizou `TestSupport` com modelo Core Data estático compartilhado para evitar avisos de entidades ambíguas.
- **Arquitetura preservada:** MVVM com SwiftUI + AppKit (`PixelTheme`) e persistência Core Data programática em `Easy Notes/Persistence/CoreDataStack.swift` (sem `.xcdatamodeld`), com *lightweight migration* automática e preservação integral de notas, cadernos, PDFs, traços e formas.

---

## 2. Matriz de Entregas, Revisões Independentes e Pull Requests

Todas as implementações e revisões rodaram em worktrees Git isolados do T3 Code, aplicando *model tiering* por complexidade (**Orchestrator (Neon)** para coordenação, implementações e revisões de persistência/AppKit; **Gemini 3.8 Flash** para re-checks pontuais e revisões de UI isolada). **Nenhum PR sofreu merge automático.**

| Ordem | Entrega | Branch / PR (rascunho) | Commit de código revisado | Parecer da Revisão Independente | XCTests aprovados (Xcode 27.2) | Documento |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | **Preparação** (XCTest + matriz) | `t3/prepare-easy-notes-tests-docs` → `main` · [PR #2](https://github.com/Fefevs09/easy-notes-ios/pull/2) | `f269874` | Baseline validada na preparação | **28/28** (11 NoteViewModel, 8 PDFExport, 4 PenColor, 5 ShapeObject) | [README.md](./README.md) |
| 1A | **FEAT-01** · Seletor personalizado de Formas | `t3/custom-shape-picker-popover-1` → `t3/prepare-easy-notes-tests-docs` · [PR #4](https://github.com/Fefevs09/easy-notes-ios/pull/4) | `4f14c43` | **Aprovado para revisão humana** (0 P1/P2; revisão em Gemini 3.8 Flash) | **31/31** (+3 `ShapePickerTests`) | [FEAT-01.md](./FEAT-01.md) |
| 1B | **FIX-01** · Renomeação e exportação PDF | `t3/fix-note-title-identity` → `t3/prepare-easy-notes-tests-docs` · [PR #3](https://github.com/Fefevs09/easy-notes-ios/pull/3) | `715f26d` | **Aprovado para revisão humana** (0 P1/P2, 3 P3 não bloqueantes; re-check em Gemini 3.8 Flash) | **31/31** (+3 `NoteViewModelTests`) | [FIX-01.md](./FIX-01.md) |
| 2 | **FEAT-03** · Capas + base para GIF | `t3/custom-note-covers` → `t3/fix-note-title-identity` · [PR #5](https://github.com/Fefevs09/easy-notes-ios/pull/5) | `53fce25` | **Aprovado para revisão humana** após ajustes de LRU/ImageIO/concorrência (0 P1/P2/P3; re-check em Gemini 3.8 Flash) | **36/36** (+5 `NoteCoverTests`) | [FEAT-03.md](./FEAT-03.md) |
| 3 | **FEAT-02** · Menu contextual próprio (nome, emoji, ações) | `t3/custom-note-action-menu` → `t3/custom-note-covers` · [PR #6](https://github.com/Fefevs09/easy-notes-ios/pull/6) | `cf97de6` *(+ commit de docs consolidado)* | **Aprovado para revisão humana** após ajustes de monitor AppKit/oclusão/foco (0 P1/P2/P3; re-check em Gemini 3.8 Flash) | **41/41** (+5 `NoteContextMenuTests`) | [FEAT-02.md](./FEAT-02.md) |

---

## 3. Contratos Arquiteturais Consolidados entre Módulos

### Formas (`FEAT-01`)
- **`ShapeKind.drawable`** (`Easy Notes/Models/ShapeObject.swift`) é a fonte única de verdade consumida por `ShapePickerNavigation` e `ShapePickerPopoverView` (`Easy Notes/Views/Toolbar/ShapePickerPopoverView.swift`).
- **`CanvasViewModel.selectShape(_ kind: ShapeKind)`** (`Easy Notes/ViewModels/CanvasViewModel.swift`) define `activeShapeKind = kind` e delega a `selectTool(.shape)`, preservando `shapeFillEnabled`, configurações por ferramenta e saída do modo leitura.
- `EditorToolbarView.exportPDF()` não foi alterado em FEAT-01 para manter zero conflito com FIX-01.

### Título, Identidade e Exportação (`FIX-01`)
- **`Note.suggestedPDFName`** (`Easy Notes/Models/Note.swift`) centraliza o nome sugerido nos dois painéis de exportação (`ContentView` e `EditorToolbarView`), retornando `"Sem título.pdf"` quando o título está vazio.
- **`NoteViewModel.editTitle(of:to:)` e `flushTitleEdits()`** (`Easy Notes/ViewModels/NoteViewModel.swift`): atualizam `note.title` e `note.updatedAt` em memória de forma imediata (garantindo consistência da exportação durante a digitação) e agrupam `context.save()` + `loadNotes()` em 500 ms, com *flush* antecipado na troca de `selectedNote`, `.onDisappear` e `NSApplication.willTerminateNotification`.
- **`NoteViewModel.renameNote(_:to:)`** opera síncrona e explicitamente sobre a instância `Note` alvo (validando contexto e `!isDeleted`, mantendo `updatedAt` intacto em no-op e revertendo em falha de save), mesmo quando outra nota está selecionada.

### Capas Personalizadas e Extensibilidade para GIF (`FEAT-03`)
- **Schema Core Data opcional (`Easy Notes/Persistence/CoreDataStack.swift`):** `coverMediaData` (`.binaryDataAttributeType`, `allowsExternalBinaryDataStorage = true`), `coverMediaType` (UTI string) e `coverUpdatedAt` (`Date`), validados via migração SQLite legado a partir de `715f26d`.
- **Camada de mídia (`Easy Notes/Models/NoteCoverMedia.swift`):**
  - `NoteCoverMedia.validated(data:contentType:)` decodifica via ImageIO e classifica `.staticImage` vs `.animatedGIF` exclusivamente a partir do tipo real dos bytes (rejeitando arquivos não-imagem ou corrompidos antes de mutar a nota).
  - `NoteCoverCache` (`@unchecked Sendable` + `NSLock`, LRU com capacidade padrão de 128 entradas) indexa por `noteID` e `EntryKind` (`.customCover` / `.pdfFallback`) sem vazamento de chaves.
  - `NoteCoverMediaRendering` e `NoteCoverRendererRegistry` (`@MainActor`) permitem plugar um futuro `AnimatedGIFCoverRenderer` registrando-o para `.animatedGIF` sem alterar Core Data, `NoteViewModel` ou os cartões.
- **API no ViewModel (`NoteViewModel`):** `setCover(for:from:)`, `setCover(for:data:contentType:)` e `removeCover(for:)`, com rollback completo em erro de persistência, invalidação de `coverCache` e preservação de `title`, `content`, `pdfData`, `strokes` e `shapes`.

### Menu Contextual Próprio e Emoji (`FEAT-02`)
- **Schema Core Data opcional:** `emoji` (`.stringAttributeType`, `isOptional = true`) na entidade `Note`, validado via migração SQLite legado a partir de `53fce25`.
- **`Note.displayEmoji`** e **`NoteViewModel.setEmoji(_:for:)`:** normalizam o texto para o primeiro `Character` (*grapheme cluster* completo, preservando ZWJ/bandeiras), gravam `nil` quando vazio/nulo, mantêm no-op idempotente preservando `updatedAt` e fazem rollback em falha de `context.save()`.
- **Menu próprio e acionamento (`NoteActionMenuPopoverView.swift` + `NotesView.swift`):**
  - `.contextMenu` nativo removido de grade e lista em `NotesView.swift` (mantendo `NoteListView.swift` intocado).
  - `NoteActionMenuModel` encapsula de forma testável as seções/ações da Biblioteca vs Lixeira e os destinos habilitados/desabilitados de `"Mover para…"`.
  - `SecondaryClickMonitorRegistry` + `SecondaryClickDetectorView` mantêm um único monitor local compartilhado com `isolated deinit`, bloqueio sob `.hiddenTitleBar` (`window.contentLayoutRect`), hit-test da janela contra o container dono e guarda contra `NSOpenPanel`/`NSSavePanel` visíveis.
  - `NoteMenuTriggerButton` atua como irmão sem aninhamento de botões, com suporte a teclado (`Return`/`Space`/`Escape`), coordenação para não roubar foco da busca (`⌘K`) e acessibilidade VoiceOver.

---

## 4. Validação de Integração Combinada (`Operator`)

Em 23/11/2026, a combinação completa das quatro entregas foi testada em um worktree temporário isolado mesclando `4f14c43` (**FEAT-01**) sobre `cf97de6` (**FEAT-02**, que já contém `f269874` → `715f26d` → `53fce25`):

- **Conflito esperado:** apenas `EasyNotesTests/TestSupport.swift` apresentou conflito de conteúdo (ambas as frentes adicionaram `makeSQLiteContainer(at:)`). A versão de `cf97de6` é superconjunto estrito (`sharedModel`, flags explícitas de lightweight migration e `coverCache: NoteCoverCache()` em `makeInMemoryViewModel()`), bastando resolvê-la com `--ours` da trilha `FIX-01 → FEAT-03 → FEAT-02`.
- **`EditorToolbarView.swift` e demais arquivos:** mesclaram automaticamente sem conflitos.
- **Resultado no Xcode 27.2 (`27B52`, macOS `arm64`):**
  - Build Debug: `** BUILD SUCCEEDED **`
  - Suíte completa combinada: **`** TEST SUCCEEDED **` — 44 testes executados, 0 falhas**
    - `NoteContextMenuTests`: 5
    - `NoteCoverTests`: 5
    - `NoteViewModelTests`: 14
    - `PDFExportTests`: 8
    - `PenColorTests`: 4
    - `ShapeObjectTests`: 5
    - `ShapePickerTests`: 3

---

## 5. Ordem Recomendada para Revisão Humana e Merge

1. **[PR #2](https://github.com/Fefevs09/easy-notes-ios/pull/2)** (`t3/prepare-easy-notes-tests-docs` → `main`) — habilita `EasyNotesTests` e inclui `7c187c7`.
2. **[PR #3](https://github.com/Fefevs09/easy-notes-ios/pull/3)** (`t3/fix-note-title-identity`) — atualização de título por identidade e exportação PDF.
3. **[PR #5](https://github.com/Fefevs09/easy-notes-ios/pull/5)** (`t3/custom-note-covers`) — capas de notas e arquitetura extensível para GIF.
4. **[PR #6](https://github.com/Fefevs09/easy-notes-ios/pull/6)** (`t3/custom-note-action-menu`) — menu contextual próprio, emoji e este índice consolidado.
5. **[PR #4](https://github.com/Fefevs09/easy-notes-ios/pull/4)** (`t3/custom-shape-picker-popover-1`) — seletor de formas; pode ser revisado em paralelo após o PR #2 (ao integrar depois do PR #5/#6, resolver `EasyNotesTests/TestSupport.swift` mantendo a versão de `FEAT-03`/`FEAT-02`).

*(Ao fechar/mesclar os PRs encadeados no GitHub, ajustar a `base` do próximo PR da fila para `main` caso o GitHub não atualize automaticamente.)*

---

## 6. Pendências, Limitações e Melhorias Opcionais

1. **Validação manual em janela macOS ao vivo (não coberta pelo `xctest` headless):**
   - Leitura e navegação ao vivo pelo **VoiceOver** na toolbar (`ShapePickerPopoverView`) e nos cartões/menu contextual (`NoteActionMenuPopoverView`).
   - Ciclo de foco físico em `NSPopover` (foco inicial ao abrir, setas/`Return`/`Space`/`Escape` e retorno do anel de foco ao botão acionador).
   - Interação real de trackpad/mouse para clique direito/`Control+clique` com rolagem sob `.hiddenTitleBar` e painéis nativos `NSOpenPanel`/`NSSavePanel` (`beginSheetModal(for:)`).
2. **Reprodução animada de GIF (escopo futuro previsto):** mídias `.animatedGIF` já são validadas, classificadas e persistidas, exibindo o quadro 0 via `StaticImageCoverRenderer` até a implementação e registro de `AnimatedGIFCoverRenderer`.
3. **Observações P3 não bloqueantes anotadas na revisão de FIX-01 (opcionais para backlog):**
   - `ContentView.swift`: aplicar cor neutra/atenuada ao rótulo `"Salvando…"` (hoje compartilha `PixelTheme.success`).
   - `NoteViewModel.swift`: resetar/reverter estado caso `context.save()` falhe em `flushTitleEdits()`.
   - `NoteViewModelTests.swift`: adicionar `XCTestExpectation` para cobrir o disparo autônomo do debounce de 500 ms sem troca de seleção.

---

## 7. Como Retomar em Outra Thread

1. Consulte este índice (`docs/entregas/README.md`) e os documentos individuais:
   - [FEAT-01.md](./FEAT-01.md) · [FIX-01.md](./FIX-01.md) · [FEAT-03.md](./FEAT-03.md) · [FEAT-02.md](./FEAT-02.md)
2. Execute a validação completa em macOS `arm64`:

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
derived_data=$(mktemp -d)
args=(-project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data")
xcodebuild "${args[@]}" build
xcodebuild "${args[@]}" -parallel-testing-enabled NO test
rm -rf "$derived_data"
```
