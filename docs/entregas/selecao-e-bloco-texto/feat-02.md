# `feat-02`: Ferramenta de Bloco de Texto (`TextBlock`)

- **Branch:** `t3/46a4a04f`
- **Commits:** `3dc0645` (implementação inicial) e `1f9ea87` (correções P1/P2/P3)

## Decisões Arquiteturais
- **Entidade Core Data programática (`TextBlock`):** definida em `Easy Notes/Models/TextBlock.swift` e registrada em `Easy Notes/Persistence/TextBlockStoreModel.swift`, com atributos `id`, `text`, `x`, `y`, `width`, `height`, `fontSize`, `colorHex`, `pageIndex`, `createdAt`, `updatedAt` e relacionamento com `Note` (`cascade` na deleção da nota).
- **Renderização compartilhada com CoreText:** `renderTextBlocks(for:pageIndex:into:excluding:)` desenha o cartão e o texto via `CTFramesetter` no espaço de coordenadas `mediaBox` da página PDF, atendendo igualmente o canvas em tela (`PageDrawingCanvas`), miniaturas (`ThumbnailBarView`) e exportação (`NoteViewModel.exportPDF`).
- **Rascunho em memória (`TextBlockEditorOverlay.swift`):** novos blocos permanecem apenas em memória até que o usuário confirme com texto não vazio; blocos vazios não geram registros fantasma no Core Data. Blocos já persistidos que forem esvaziados restauram o texto original para evitar perda acidental.
- **Ferramenta dedicada na barra (`ToolType.textBox`):** integra cor via `PenColorToolContext.textBox` e seletor de tamanho de fonte (`12...36 pt`) na barra contextual de `EditorToolbarView`, além de contagem/desfazer em `NoteViewModel.drawnObjectCount` e `undoLastObject()`.

## Migração Core Data
- `CoreDataStack.makeModel()` estende `makeEditorImageModel()` com `addTextBlockEntity(to:)`.
- `EditorImageStoreModel.swift` adiciona `makeEditorImageSource()` à lista `supportedSources` de `migrateBaseStoreIfNeeded(at:to:)`, garantindo migração automática com `NSMappingModel(from:forSourceModel:destinationModel:)` a partir de bancos históricos antigos e de bancos já na versão de `EditorImage` (PR #22).

## Ciclo de Vida da Edição Inline
- `InlineTextBlockTextView` (`NSTextView`) trata `cancelOperation` respeitando composição de teclado/IME (`hasMarkedText()` descarta apenas o texto marcado antes de encerrar com `Escape`) e implementa `performKeyEquivalent` para `⌘A`, `⌘C`, `⌘V`, `⌘X`, `⌘Z` e `⇧⌘Z` dentro do `PDFView`.
- `PDFAnnotationCanvasView.Coordinator` registra `onCommitActiveTextEdits` e `onRestoreTextEditorFocus` no `CanvasViewModel`, além de observar mudanças de ferramenta, modo de leitura, fonte e cor.
- `EditorToolbarView` e `ContentView` garantem commit síncrono antes de exportar PDF, desfazer objeto, voltar à biblioteca, desaparecer a view ou encerrar o app (`willTerminateNotification`).
- Durante a abertura dos popovers de cor ou tamanho da fonte em `.textBox`, `isTextStylePopoverPresented` mantém o editor inline aberto sem finalizar prematuramente e restaura o foco no editor ao fechar o popover.

## Achados de Revisão Resolvidos (`1f9ea87`)
- **P1:** prevenção de perda de dados em navegação/exportação/fechamento via hooks síncronos de commit e limpeza segura em `dismantleNSView` / `clearCache(deferPublishedUpdates:)`.
- **P2:** alinhamento de geometria sob zoom e `mediaBox` deslocado (`updateOverlayGeometry`), expansão vertical automática que desloca para cima ao atingir a margem inferior da página e revisão de miniaturas com `textBlockTimestamps`.
- **P3:** suporte a IME em `Escape`, atalhos de edição (`⇧⌘Z` Redo) e proteção contra exclusão silenciosa de blocos existentes esvaziados.

## Cobertura de Testes (`EasyNotesTests/TextBlockTests.swift`)
- CRUD completo, reabertura SQLite e deleção em cascata.
- Migração de bancos SQLite históricos (pré-capa/grid e pós-`EditorImage`) para o schema com `TextBlock` sem perda de dados.
- `drawnObjectCount` e `undoLastObject()` em ordem cronológica entre `Stroke`, `ShapeObject` e `TextBlock`.
- Renderização e exportação PDF com texto legível e omissão de rascunhos vazios.
- Prevenção de persistência vazia em rascunhos e restauração de texto original em blocos existentes.
- Alinhamento com zoom `1.5x` e `mediaBox` deslocado, hook de commit e expansão vertical perto da margem inferior.
- Manutenção do editor aberto durante popovers de estilo, sincronização de fonte/cor e restauração de foco.
- `⌘⇧Z` Redo e `Escape` com `markedText` ativo, além de limites de `defaultFrame` e `clampedFrame`.
