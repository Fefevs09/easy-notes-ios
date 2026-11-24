# Exportação de PDF — validação

Base: `c481d0c786dc22062474fca9daadc1c4bb35228e`. O objetivo é exportar as páginas e anotações visíveis sem alterar a nota, preservando a biblioteca original. O plano transversal está em `plano-pdf-configuracoes.md`; os registros FEAT-01 e FEAT-02 permanecem inalterados.

## Fluxo e contratos inspecionados

Os comandos Compartilhar no editor, Mais opções na barra e Exportar no menu da nota apresentam `NSSavePanel` e chamam `NoteViewModel.exportPDF`. O exportador abre uma cópia dos dados armazenados, desenha cada página e aplica grade, formas e traços filtrados pelo índice da página. A saída é escrita com `Data.write(options: .atomic)`; erros são apresentados ao usuário. Cancelar retorna antes de chamar o exportador. O menu da nota restaura o foco após o painel. Esses contratos de interface e escrita foram inspecionados no código, não exercitados interativamente.

O texto incorporado a PDFs importados faz parte das páginas; a importação inicializa `note.content` vazio e não duplica o texto do PDF nesse campo. O campo legado `note.content` aparece na prévia do cartão, mas não no canvas. Antes da correção, uma nota só com esse campo gerava PDF vazio. Conforme decisão da coordenadora, o texto legado não vazio agora é paginado em texto selecionável após todas as páginas originais e suas anotações, sem sobreposição. Se não há PDF armazenado, traços, formas ou grade, o texto começa na primeira página, sem folha em branco artificial. Não há alteração da nota.

## Evidências

- Os oito testes originais de `PDFExportTests` verificam PDF inválido, saída válida, contagem de páginas, traço, isolamento de traço por página, forma preenchida, sucesso com grade e falha de destino. O teste de grade original não verifica pixels.
- `PageThumbnailTests.testCustomGridInkReachesThumbnailsAndExport` verifica a cor da grade na saída; `ShapePickerTests.testDrawingAllDrawableShapesAcrossPagesPersistsOnReopenAndRendersInExportedPDF` verifica formas em duas páginas e reabertura de armazenamento temporário.
- Novos testes verificam texto incorporado em duas páginas importadas, traço restrito à segunda página e ausência de mutação dos campos observados; fonte inválida preserva arquivo existente. Cobrem também paginação de texto legado e texto misto após duas páginas com anotação.
- Executado com Xcode em `/Applications/Xcode.app/Contents/Developer`, destino macOS, assinatura desligada, DerivedData em `~/.capy/work/pdf-validation/DerivedData` e testes sem paralelismo. Os testes usam Core Data em memória ou SQLite sob diretório temporário, não a biblioteca pessoal. Comando: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS' -derivedDataPath "$HOME/.capy/work/pdf-validation/DerivedData" -only-testing:EasyNotesTests/PDFExportTests -only-testing:EasyNotesTests/PageThumbnailTests -only-testing:EasyNotesTests/ShapePickerTests -only-testing:EasyNotesTests/NewNoteTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO`.
- A execução inicial passou 17 testes; após a correção, passaram 21. Houve avisos de PDFPage sem documento e serviço AppIntents indisponível, sem falhas nesses testes.

## Pendências

- Exercitar mouse e teclado nos três pontos de entrada, inclusive cancelar e restaurar foco, usando uma biblioteca descartável; a inspeção estática não prova a navegação real.
- A opção de escrita atômica é usada, mas interrupção durante a troca e erros de escrita após geração não foram simulados. O teste de fonte inválida comprova somente que a falha anterior à escrita preserva o destino.
- Comparar visualmente PDFs importados complexos, incluindo rotação e caixas de página não convencionais; os testes não cobrem todas as variantes PDFKit.
