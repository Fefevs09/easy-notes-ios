# FEAT-01 · Seletor personalizado de Formas geométricas

Base Git utilizada: `f269874` (`t3/prepare-easy-notes-tests-docs`).

## Objetivo

Substituir o `Menu` nativo (`shapesMenu`) em `EditorToolbarView.swift` por um botão acionador customizado e um popover próprio alinhados ao sistema visual `PixelTheme`, preservando todas as funcionalidades existentes de desenho, preenchimento, seleção de formas, cor, espessura, modo leitura e exportação PDF.

## Decisões de UI e Arquitetura

- **Estética editorial e tokens do tema (`PixelTheme`):**
  - Extraído o componente completo para `Easy Notes/Views/Toolbar/ShapePickerPopoverView.swift`, compilado automaticamente nos targets `Easy Notes` e `EasyNotesTests` via `PBXFileSystemSynchronizedRootGroup`.
  - O popover usa fundo `PixelTheme.paper`, card `.studioCard(fill: PixelTheme.paper, radius: PixelTheme.cardRadius, borderColor: PixelTheme.border)`, cabeçalho `"Formas geométricas"` com badge `"Ativa"` (`PixelTheme.accentSoft` / `PixelTheme.accentDeep`) quando `.shape` está selecionada e dica compacta de navegação por teclado.
- **Estados visuais distintos:**
  - **Botão acionador (`ShapePickerTriggerButton`):** aplica `.studioActiveTool(contextualTool == .shape)`, mostra o ícone da `activeShape` quando a ferramenta `.shape` está ativa ou `"square.on.circle"` quando inativa, exibe chevron com rotação conforme estado aberto/fechado e anel de foco de teclado explícito (`PixelTheme.accent`, 2pt) quando focado.
  - **Opções no popover (`ShapePickerPopoverView`):** diferenciam claramente estado selecionado (fundo `PixelTheme.accentSoft`, texto e ícone `PixelTheme.accentDeep` + checkmark), hover (`PixelTheme.surface` + borda `PixelTheme.border`) e foco de teclado (borda explícita `PixelTheme.accent` / `PixelTheme.accentBorder` de 2pt com `focusEffectDisabled()`).
- **Coordenação de popovers:**
  - Abrir o seletor de formas fecha `isColorPopoverPresented`, `isSizePopoverPresented` e `isNoteSettingsPresented`.
  - Abrir qualquer um desses outros popovers, trocar de nota (`viewModel.selectedNote?.id`), selecionar outra ferramenta na barra principal ou alternar para outra ferramenta contextual diferente de `.shape` fecha o seletor de formas.
- **Teclado, foco e VoiceOver:**
  - Botão acionador focável (`.focusable()`), abrindo o popover via clique, `Return` ou `Space`.
  - Foco inicial dentro do popover na forma ativa (`@FocusState` + `.defaultFocus`), navegação cíclica por setas `upArrow`/`downArrow` via helper puro `ShapePickerNavigation.steppedShape(from:direction:in:)`, confirmação com `Return`/`Space` e cancelamento com `Escape` (`.onExitCommand` e `.onKeyPress(.escape, phases: .down)`).
  - Ao confirmar via teclado ou cancelar via `Escape`, o popover fecha e restaura o foco no botão acionador de forma assíncrona na fila principal (`DispatchQueue.main.async` + `MainActor.assumeIsolated`).
  - Acessibilidade configurada com `accessibilityLabel("Formas geométricas")`, `accessibilityValue` dinâmico (`activeShape.displayName` ou `"Inativa"`), `.accessibilityAddTraits(.isSelected)` no botão e na opção ativa, `.help("Formas geométricas")` e identificadores estáveis (`shape-picker-trigger`, `shape-picker-popover`, `shape-option-<kind>`).

## Contrato entre Toolbar/Popover e `CanvasViewModel`

- **Fonte única das opções:** `ShapePickerPopoverView` e `ShapePickerNavigation` consomem exclusivamente `ShapeKind.drawable` (`[.line, .rectangle, .ellipse, .arrow]`), sem duplicar a lista manualmente.
- **API de seleção no ViewModel:** `CanvasViewModel.selectShape(_ kind: ShapeKind)` define `activeShapeKind = kind` e chama `selectTool(.shape)`, garantindo saída do modo leitura (`isDrawingMode = true`), limpeza de `selectedShapeID`, restauração de espessura/cor configuradas para `.shape` e preservação de `shapeFillEnabled`.
- **Preservação de `exportPDF()`:** `EditorToolbarView.exportPDF()` não foi modificado nesta entrega para evitar conflitos de merge com `FIX-01` (PR #3).

## Arquivos Alterados e Criados

- `Easy Notes/ViewModels/CanvasViewModel.swift` — adição de `public func selectShape(_ kind: ShapeKind)`.
- `Easy Notes/Views/Toolbar/ShapePickerPopoverView.swift` — novo componente (`ShapePickerNavigation`, `ShapePickerTriggerButton`, `ShapePickerPopoverView`).
- `Easy Notes/Views/Toolbar/EditorToolbarView.swift` — substituição de `shapesMenu` por `shapePickerButton`, restauração de foco e coordenação de popovers (sem alterar `exportPDF()`).
- `EasyNotesTests/TestSupport.swift` — adição de `makeSQLiteContainer(at:)` reutilizando o modelo compartilhado para testes de reabertura persistida.
- `EasyNotesTests/ShapePickerTests.swift` — novos testes cobrindo `CanvasViewModel.selectShape(_:)`, navegação cíclica/apresentação e fluxo completo de desenho de todas as formas em `PageDrawingCanvas`, persistência/reabertura em novo `NSManagedObjectContext` e exportação PDF.
- `docs/entregas/FEAT-01.md` — documentação desta entrega.

## Validação no Xcode 27.2 (macOS arm64)

Ambiente verificado em 23/11/2026: Xcode 27.2 (`27B52`), macOS 27.2.1 (`arm64`).

Comando executado na raiz do worktree:

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
derived_data=$(mktemp -d)
args=(-project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data")
xcodebuild "${args[@]}" build && xcodebuild "${args[@]}" -parallel-testing-enabled NO test
rm -rf "$derived_data"
```

Resultado observado:
- Build: `** BUILD SUCCEEDED **`
- Testes: `** TEST SUCCEEDED **` — **31 XCTests executados, 0 falhas** (`NoteViewModelTests`: 11, `PDFExportTests`: 8, `PenColorTests`: 4, `ShapeObjectTests`: 5, `ShapePickerTests`: 3), sem avisos de entidades Core Data ambíguas.

## Limitações Conhecidas

- A suíte XCTest cobre a seleção via `CanvasViewModel.selectShape(_:)`, a lógica pura de navegação cíclica/ícones/acessibilidade e o ciclo completo de desenho em `PageDrawingCanvas` + persistência SQLite + exportação PDF.
- Permanecem pendentes de validação manual em janela macOS interativa ao vivo: leitura completa pelo VoiceOver, foco físico inicial dentro do `NSPopover`, navegação real por setas/Return/Space/Esc e retorno do anel de foco ao botão acionador após `Escape`.
