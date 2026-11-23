# FEAT-02 · Menu contextual próprio com nome, emoji e ações adicionais

## Substituição do menu contextual nativo

O modificador nativo `.contextMenu { contextMenuContent(for: note) }` foi removido de `Easy Notes/Views/NoteList/NotesView.swift` (grade e lista) e substituído pelo componente modular `Easy Notes/Views/NoteList/NoteActionMenuPopoverView.swift`, alinhado aos tokens de `PixelTheme` (`PixelTheme.paper`, `PixelTheme.surface`, `PixelTheme.accent`, `PixelTheme.accentSoft`, `PixelTheme.accentBorder`, `PixelTheme.danger`, `PixelTheme.dangerSoft`, `PixelTheme.border`, `PixelTheme.uiFont` e `PixelTheme.displayFont`).

### Arquitetura de acionadores, teclado, foco e acessibilidade

- **Coordenação única de estado (`NotesView`):** `@State private var activeMenuNoteID: UUID?` garante no máximo um menu aberto por vez. Abrir o menu de outra nota fecha o anterior; alterações em `viewModel.selectedFilter`, `viewModel.searchQuery`, `viewModel.selectedNote`, `isGridView` ou remoção do item em `viewModel.notes` fecham qualquer popover aberto.
- **Clique secundário AppKit (`SecondaryClickOverlay` / `SecondaryClickDetectorView`):** `NSViewRepresentable` com `hitTest(_:)` retornando `nil` (sem interferir em clique esquerdo, hover, `.onDrag` ou foco) e `NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown])`. O monitor filtra clique direito ou `Control+clique`, verifica `event.window === window`, ausência de modal/sheet ativo, visibilidade do item e `bounds.contains(localPoint) && visibleRect.contains(localPoint)`, consumindo o evento e disparando a abertura assíncrona na fila principal. O monitor é removido tanto em `viewWillMove(toWindow: nil)` quanto em `dismantleNSView(_:coordinator:)`.
- **Botão `"ellipsis"` dedicado e sem aninhamento de botões (`NoteMenuTriggerButton`):** `NoteCardView` e `NoteListRowCardView` foram reestruturados para manter o botão principal de abertura da nota e o botão `"ellipsis"` como irmãos (`ZStack` na grade e `HStack` na lista). O botão `"ellipsis"` é focável (`.focusable()` + `@FocusState`), responde a clique, `Space` e `Return` (`.onKeyPress(.return)`), exibe anel de foco e possui `accessibilityLabel("Ações da nota \(displayTitle)")` e `.help("Opções da nota")`.
- **VoiceOver, `Escape` e devolução de foco:** os cartões e linhas expõem `.accessibilityAction(named: "Opções da nota")` no botão principal. Dentro de `NoteActionMenuPopoverView`, o container recebe foco inicial via `.defaultFocus($focusedField, .container)` e `.onExitCommand(perform: onClose)` (presente também nos campos de texto), descartando rascunhos não salvos ao pressionar `Escape` ou cancelar. Ao fechar o popover (ou concluir `NSOpenPanel`/`NSSavePanel`), o foco retorna assincronamente na fila principal para o botão acionador da nota quando ela permanece na lista ativa.
- **Exibição de emoji nos itens:** `NoteCardView` e `NoteListRowCardView` exibem `note.displayEmoji` discretamente antes do título apenas quando definido, preservando o layout original quando `emoji == nil`.
- **Arquivo legado preservado:** `Easy Notes/Views/NoteList/NoteListView.swift` não foi alterado.

## Integração com FIX-01 e FEAT-03 e regras de apresentação (`NoteActionMenuModel`)

Todas as ações capturam explicitamente o objeto `Note` do item acionado, atuando sobre ele mesmo quando outra nota está selecionada no `NoteViewModel`:

- **Modo Lixeira (`viewModel.selectedFilter == .trash`):** cabeçalho somente leitura com emoji (se houver) + título e ações **"Restaurar Nota"** (`viewModel.restoreNote(note)`) e **"Excluir Definitivamente"** (`viewModel.deleteNote(note)`).
- **Fora da Lixeira:**
  - **Nome (contrato FIX-01):** campo inicializado com `note.title`, confirmação explícita via `Return` ou botão **"Salvar"** chamando `try viewModel.renameNote(note, to: draftTitle)` (preservando a sugestão `note.suggestedPDFName`). Cancelar ou pressionar `Escape` descarta o rascunho sem mutar `note.title` ou `updatedAt`. Falhas exibem alerta inline sem fechar o popover.
  - **Emoji (contrato FEAT-02):** grade rápida curada (`["📝", "📚", "💡", "🎯", "✅", "📌", "🔬", "🎨", "🧠", "🗓️", "⭐️", "🔥"]`) destacando o selecionado, botão **"Remover emoji"** quando `note.displayEmoji != nil` e campo compacto para qualquer grapheme cluster (`"Outro emoji…"` + **"Usar"**), chamando `try viewModel.setEmoji(..., for: note)`.
  - **Capa (contrato FEAT-03):** **"Escolher capa…"** / **"Trocar capa…"** (abre `NSOpenPanel` com `NoteCoverMedia.supportedStaticImageTypes` e chama `try viewModel.setCover(for: note, from: url)`) e **"Remover capa"** quando `note.hasCustomCover` (`try viewModel.removeCover(for: note)`), com alertas claros de erro preservando a capa anterior.
  - **Exportar PDF (contrato FIX-01):** **"Exportar como PDF…"** abre `NSSavePanel` preenchido com `note.suggestedPDFName` e chama `try viewModel.exportPDF(for: note, to: url)`.
  - **Mover para…:** seção expansível no próprio popover acessível por teclado listando **"Notas Soltas"** (desabilitado e marcado quando `note.notebook == nil`) e cada caderno de `viewModel.notebooks` com dot de `PixelTheme.notebookColor(for:)` (desabilitado e marcado quando `note.notebook == notebook`), chamando `viewModel.moveNote(note, to: ...)`.
  - **Excluir Nota:** ação destrutiva com `PixelTheme.danger` chamando `viewModel.deleteNote(note)`.

## Core Data (`emoji`) e migração SQLite legado

- `Easy Notes/Persistence/CoreDataStack.swift` (`makeModel()`) adicionou apenas o atributo opcional `emoji` (`.stringAttributeType`, `isOptional = true`) na entidade `Note`, sem alterar atributos ou relacionamentos existentes, mantendo lightweight migration automática.
- `Easy Notes/Models/Note.swift` expõe `@NSManaged public var emoji: String?` e o helper somente leitura `public var displayEmoji: String?` (retorna `nil` quando nulo ou vazio após trim).
- `Easy Notes/ViewModels/NoteViewModel.swift` implementa `public static func normalizedEmoji(_ raw: String?) -> String?` e `public func setEmoji(_ emoji: String?, for note: Note) throws`:
  - Valida `note.managedObjectContext === context && !note.isDeleted` (lançando `CocoaError(.managedObjectReferentialIntegrity)`).
  - Remove espaços nas bordas; grava `nil` se vazio/`nil`, ou o primeiro `Character` (grapheme cluster completo, preservando ZWJ, bandeiras e seletores de variação).
  - Retorna em no-op idempotente sem alterar `updatedAt` quando `note.emoji == normalized`.
  - Salva com `try context.save()`, realiza rollback completo de `emoji` e `updatedAt` em caso de falha antes de relançar e chama `loadNotes()` em sucesso sem modificar `title`, `content`, `pdfData`, `coverMediaData`, `strokes`, `shapes` ou `notebook`.
- A migração SQLite legado foi comprovada em `NoteContextMenuTests.testLegacyPreEmojiSQLiteStoreMigratesAndPreservesCoverAndEntities` a partir de um store criado com cópia fiel do modelo da base `53fce25` (com atributos de capa e sem `emoji`), verificando preservação integral de `Notebook`, `Note`, capa PNG, PDF, `Stroke` e `ShapeObject` após lightweight migration e persistência de novo emoji após reabertura do SQLite.

## Verificação no macOS

Em 23/11/2026, com Xcode 27.2 (`27B52`) em macOS `arm64`:

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
derived_data=$(mktemp -d)
args=(-project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data")
xcodebuild "${args[@]}" build
xcodebuild "${args[@]}" -parallel-testing-enabled NO test
```

- Build Debug: `** BUILD SUCCEEDED **`.
- Suíte XCTest (`EasyNotesTests`): **40 testes executados, 0 falhas** (`NoteContextMenuTests`: 4, `NoteCoverTests`: 5, `NoteViewModelTests`: 14, `PDFExportTests`: 8, `PenColorTests`: 4, `ShapeObjectTests`: 5).
- Sem avisos de ambiguidade de entidades Core Data durante a migração SQLite ou nos testes em memória.

## Limitações conhecidas

- A interação física de clique direito/`Control+clique`, foco visual/teclado dentro do `NSPopover`, devolução real de foco pelo AppKit após fechar o popover, leitura ao vivo pelo VoiceOver e fluxos interativos dos painéis `NSOpenPanel`/`NSSavePanel` no aplicativo macOS em execução foram verificados por compilação e revisão de código; os testes automatizados cobrem em nível de modelo, persistência, migração SQLite, contrato de ações e regras de apresentação (`NoteActionMenuModel`).
