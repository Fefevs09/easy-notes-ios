# Criar nota

Na biblioteca ou na lista de notas, selecione **Nova nota**. Escolha o papel (liso, pautado, quadriculado ou pontilhado) e a orientação. A prévia acompanha as escolhas. O título é opcional.

**Criar nota** (Return) salva e abre a nota no caderno ativo. Nos filtros gerais, a nota fica em **Notas Soltas**. **Cancelar** (Esc) descarta as escolhas.

A folha usa o formato Carta, com 612 × 792 pontos na vertical ou 792 × 612 na horizontal. As páginas adicionadas seguem as dimensões da primeira folha. A exportação PDF inclui o padrão de papel de cada nota.

## Verificação regressiva de miniatura

Adicionado teste XCTest para a miniatura de uma página horizontal com traço em x=700, verificando pixels no lado direito da imagem renderizada em store Core Data descartável.

Resultado: `xcodebuild test -project "Easy Notes.xcodeproj" -scheme "Easy Notes" -destination "platform=macOS,arch=arm64" -only-testing:EasyNotesTests/PageThumbnailTests/testLandscapeThumbnailIncludesStrokeNearRightEdge` — **TEST SUCCEEDED** (1 teste, 0 falhas; 23/11/2026).
