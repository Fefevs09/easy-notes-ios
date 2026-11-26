# Integração: Seleção Unificada (`feat-01`) + Blocos de Texto (`feat-02`)

## Resumo Executivo
Esta entrega integra a seleção unificada de objetos no canvas (`feat-01`) e a ferramenta de blocos de texto inline com persistência Core Data (`feat-02`) em uma base única, conectando `TextBlock` ao contrato `CanvasObjectRef.textBlock(UUID)` para seleção, movimentação em grupo, atalhos de teclado e cancelamento seguro.

## Base Git e Ordem de Merge
- **Base comum:** `main` (`b9ced9b` — Merge PR #22 `t3/persist-editor-images`).
- **Ordem de integração neste worktree:**
  1. Fast-forward de `feat-01` (`5e0d75b`, branch `t3/54894431`).
  2. Merge de `feat-02` (`1f9ea87`, branch `t3/46a4a04f`) com resolução manual de conflitos em `CanvasViewModel.swift`, `PDFAnnotationCanvasView.swift` e `EditorToolbarView.swift`.
  3. Conexão de `.textBlock(UUID)` em `CanvasSelectionController.swift`, commit automático de edição ativa antes de selecionar, duplo clique no `.select` para abrir edição inline de `TextBlock` e novos testes de integração em `CanvasSelectionTests.swift`.

## Matriz de Entregas

| Entrega | Branch / SHA | Escopo Principal | Documentação Detalhada |
| :--- | :--- | :--- | :--- |
| `feat-01` | `t3/54894431` (`5e0d75b`) | Seleção única/múltipla (`Stroke`, `ShapeObject`, `EditorImage`), marquee, mover com Seleção ou Caneta, resize, teclado e cursor | [feat-01.md](./feat-01.md) |
| `feat-02` | `t3/46a4a04f` (`1f9ea87`) | Entidade `TextBlock`, migração explícita SQLite, edição inline `NSTextView`, renderização CoreText e exportação PDF | [feat-02.md](./feat-02.md) |

## Contratos Entre Módulos
- **`CanvasObjectRef` (`CanvasViewModel.swift`):** enum `Hashable` com casos `.stroke(UUID)`, `.shape(UUID)`, `.image(UUID)` e `.textBlock(UUID)`.
  - `selectedObjects: Set<CanvasObjectRef>` e `selectedPageIndexForSelection: Int?` controlam a seleção ativa por página.
  - Trocar para `.eraser`, `.shape` ou `.textBox` limpa a seleção (`clearSelection()`); trocar de `.select` para ferramentas de caneta preserva a seleção para permitir arraste direto com a caneta dentro do bounding box.
- **Ordem de Hit-Test (Z-order em `CanvasSelectionController.swift`):**
  1. `TextBlock` (topo, mais recente primeiro)
  2. `Stroke`
  3. `ShapeObject`
  4. `EditorImage` (base)
- **Coordenadas de `TextBlock`:** persistido em coordenadas nativas da página PDF (`mediaBox`, origem inferior esquerda), convertido para coordenadas da overlay via `pageToOverlayTransform` durante hit-test, renderização da seleção e arraste/nudge.
- **Ciclo de Vida Inline x Seleção:**
  - Iniciar interação com ferramentas não-`.textBox` em `PageDrawingCanvas.mouseDown` chama `commitTextEditorIfNeeded()` e `canvasVM.commitActiveTextEdits()` antes de iniciar seleção ou traço.
  - Duplo clique sem modificadores sobre um `TextBlock` no modo `.select` cancela o drag pendente, limpa a seleção, ativa `.textBox` e abre a edição inline.
- **Migração Explícita SQLite (`EditorImageStoreModel.swift` + `TextBlockStoreModel.swift`):** `CoreDataStack.makeModel()` combina `makeEditorImageModel()` com `addTextBlockEntity(to:)`, e `migrateBaseStoreIfNeeded(at:to:)` inclui `makeEditorImageSource()` para migrar lojas legadas e pós-PR #22 sem perda de dados.

## Validações no Xcode
- Build e suíte completa de testes executados via `xcodebuild` para `platform=macOS,arch=arm64` com `-parallel-testing-enabled NO` após a integração final (incluindo `CanvasSelectionTests` e `TextBlockTests`).

## Pendências de Verificação Manual (Janela macOS ao Vivo)
- Verificar visualmente em janela interativa com `PDFView` real em diferentes níveis de zoom e rotação:
  - Transição do cursor (`.arrow`, `.openHand`, `.closedHand`, `.crosshair`, `.iBeam`) sobre `TextBlock` selecionado e ao redor de handles.
  - Comportamento de IME (acentos/marked text) e popovers de cor/fonte durante edição inline de `TextBlock` após duplo clique via `.select`.
  - Atualização visual das miniaturas na `ThumbnailBarView` imediatamente após mover ou excluir um `TextBlock` selecionado.
