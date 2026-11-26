# FEAT-01 · Imagens nas páginas do editor

Base aprovada `49aa07043df58515cf506b43541375322a90eb21`. A implementação está na branch `t3/persist-editor-images`, em `/Users/felipevieira/.t3/worktrees/easy-notes-ios/t3-16851880-fc0030fc9dabbf37`.

## Contratos

- A barra do editor oferece **Inserir imagem** com rótulo de acessibilidade e atalho ⇧⌘I. O seletor nativo recebe um PNG ou JPEG e a ação captura a nota e a página ativas ao abri-lo.
- A importação valida o formato e a completude da imagem e limita a entrada a 20 MB, 8.192 pixels por lado e 24 megapixels. O retângulo começa centralizado na página, preserva a proporção com a orientação EXIF e ocupa até 320 pontos e 70% de cada dimensão da página. A leitura em disco é limitada e o cache de renderização usa bitmaps de até 2.048 pixels por lado.
- `EditorImage` guarda o arquivo original, a nota proprietária, o índice da página a partir de zero e o retângulo em pontos da media box do PDF. A exclusão permanente da nota remove suas imagens. A importação usa um contexto de gravação isolado e mescla o resultado depois do save. Cancelamento, mídia inválida e falha de save não alteram a nota nem salvam ou descartam edições pendentes.
- `renderEditorImages(for:pageIndex:into:)` recebe um contexto em coordenadas nativas da media box. Canvas, miniatura de página e exportação chamam esse renderer depois do papel e da grade e antes das formas e dos traços. Canvas usa a conversão do PDFKit. A exportação normaliza a apresentação de páginas rotacionadas ou com origem deslocada para alinhar o papel e as camadas renderizadas. A imagem acompanha a orientação da página. O PDF original e a capa da biblioteca são armazenados separadamente.
- `CoreDataStack.makeBaseModel()` conserva o schema da base. A abertura compara os hashes do SQLite com os modelos conhecidos. Para um schema anterior, infere o mapeamento explicitamente, migra num diretório temporário ao lado do banco e usa a operação de substituição do Core Data, que inclui os binários externos. Um schema desconhecido retorna erro antes da substituição.

## Integração com pressão

Ao combinar as branches, preserve `makeBaseModel()` com os hashes de `49aa070`. Acrescente ambas as extensões ao destino de `makeModel()` e migre da base diretamente para o schema combinado. Se um schema intermediário já tiver sido distribuído, inclua o modelo correspondente como fonte histórica. Em `PageDrawingCanvas.draw(_:)` e na exportação, mantenha o renderer de imagens entre a grade e as formas e execute o renderer de pressão na posição dos traços. A conversão do canvas para a camada de mídia fica dentro de um par `saveGState` e `restoreGState`, de modo que os desenhos interativos continuam usando o seu próprio espaço de coordenadas.

## Verificação e retomada

Execute a suíte macOS arm64 com DerivedData isolado. Os testes de armazenamento abrem SQLite temporários e a suíte usa um bundle XCTest independente.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/easynotes-feat01-16851880 \
  test CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO
```

Para a conferência manual, abra uma nota de teste com duas páginas, navegue até a segunda, acione ⇧⌘I, selecione um PNG/JPEG e confira a página, a miniatura e o PDF exportado. Passe pelo botão e pelo seletor com teclado e VoiceOver. Teste também Cancelar e um arquivo truncado.

### Resultado

- Commit revisável de código e testes `123625ede53d158a86bfc0407e741efe8c44451a`.
- Xcode 27.2, macOS arm64. **85 testes passaram**. Os novos testes cobrem migração e reabertura do SQLite, preservação da capa externa, PDF, hierarquia, formas e traços, exclusão em cascata, mídia inválida, falha real de save com store somente leitura e saída do canvas PDFKit, da miniatura e do PDF com página deslocada e rotacionada.
- Pendente a conferência manual de VoiceOver e do seletor de arquivos. Nenhum banco do usuário foi aberto.
