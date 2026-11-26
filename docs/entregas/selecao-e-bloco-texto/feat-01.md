# `feat-01`: Seleção Unificada e Movimentação no Canvas

- **Branch:** `t3/54894431`
- **Commits:** `b6a46e9` (implementação inicial) e `5e0d75b` (correções de revisão)

## Decisões Arquiteturais
- **Modelo de seleção tipado (`CanvasObjectRef`):** substituiu o antigo `selectedShapeID` único por `selectedObjects: Set<CanvasObjectRef>` e `selectedPageIndexForSelection: Int?` em `CanvasViewModel`, mantendo `selectedShapeID` como propriedade computada de compatibilidade para seleção única de forma.
- **Controller dedicado (`CanvasSelectionController.swift`):** isolou hit-test, marquee retangular, bounding box de grupo, arraste de translação, resize por handles (vértices de `ShapeObject` e cantos de `EditorImage` com preservação de proporção e mínimo `24 pt`), atalhos de teclado e desenho da moldura de seleção fora de `PageDrawingCanvas`.
- **Preservação de seleção ao alternar para Caneta:** ao sair de `.select` para `.fountainPen`, `.calligraphy`, `.pencil` ou `.highlighter`, a seleção permanece ativa; arrastar dentro da caixa de seleção move os objetos com a caneta, enquanto arrastar fora limpa a seleção e cria um novo traço.
- **Transformações em páginas rotacionadas/deslocadas:** imagens (e após a integração, blocos de texto) usam `pageToOverlayTransform` e sua inversa para manter precisão pixel a pixel entre overlay e PDF exportado.

## Arquivos Principais (`feat-01`)
- `Easy Notes/ViewModels/CanvasViewModel.swift`
- `Easy Notes/Views/Editor/CanvasSelectionController.swift`
- `Easy Notes/Views/Editor/PDFAnnotationCanvasView.swift`
- `Easy Notes/Views/Toolbar/EditorToolbarView.swift`
- `Easy Notes/ContentView.swift`
- `EasyNotesTests/CanvasSelectionTests.swift`

## Achados de Revisão Resolvidos (`5e0d75b`)
1. **Cursor após sair da seleção ou cancelar:** `PageDrawingCanvas` e `NSPDFAnnotationView` agora retornam explicitamente para `.arrow` ao sair da caixa de seleção no modo `.select` ou ao pressionar `Escape`.
2. **Cancelamento de drag com `Escape` sem sujar o contexto:** `cancelActiveDrag` verifica se todos os objetos estavam limpos antes do drag e usa `moc.rollback()` com segurança (ou restaura snapshots individuais / `moc.refresh`) mantendo `context.hasChanges == false`.
3. **Guardas em `handleKeyDown`:** ignora atalhos quando há modificadores `.command`, `.option` ou `.control` ativos, ou quando `firstResponder is NSText` (ex.: edição de título da nota ou bloco de texto).
4. **Reset de seleção entre notas e páginas:** `ContentView.resetEditorPosition()` chama `canvasVM.clearSelection()` na troca de nota; `redrawAll()` cancela drag ativo se a ferramenta atual não suportar seleção.

## Cobertura de Testes (`EasyNotesTests/CanvasSelectionTests.swift`)
- Hit-test e seleção simples entre `Stroke`, `ShapeObject` e `EditorImage`, com prioridade para o mais recente em sobreposições.
- `Shift+Click` e marquee com movimentação simultânea em grupo e persistência de `note.updatedAt`.
- Preservação da seleção ao alternar para ferramentas de caneta (arraste interno move, externo desenha) e limpeza em outra página.
- Redimensionamento de handle de forma e resize proporcional de imagem (`>= 24 pt`).
- Nudge (`1 pt` / `10 pt` com `Shift`), `Escape`, `Delete`/`Backspace`, guardas de modificadores e `NSText` first responder.
- Movimentação em página rotacionada com `mediaBox` deslocado validada por amostragem de pixels no PDF exportado.
- Seleção, movimentação, grupo misto, Z-order, cancelamento com `Escape` e deleção integrados para `TextBlock`.
