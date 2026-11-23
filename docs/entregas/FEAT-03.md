# FEAT-03 · Capas personalizadas das notas e base preparada para GIF

## Esquema Core Data e prova de migração SQLite legado

Para preservar a compatibilidade com stores SQLite já existentes sem arquivo `.xcdatamodeld`, `CoreDataStack.makeModel()` adicionou apenas três atributos opcionais à entidade `Note`, mantendo `shouldMigrateStoreAutomatically = true` e `shouldInferMappingModelAutomatically = true`:

| Atributo | Tipo Core Data | Opcional | Observação |
| --- | --- | --- | --- |
| `coverMediaData` | `.binaryDataAttributeType` | `true` | `allowsExternalBinaryDataStorage = true` para armazenar imagens e futuros GIFs sem inflar o registro inline. |
| `coverMediaType` | `.stringAttributeType` | `true` | Identificador UTI da mídia persistida (ex.: `public.png`, `public.jpeg`, `com.compuserve.gif`). |
| `coverUpdatedAt` | `.dateAttributeType` | `true` | Token de atualização usado para invalidação determinística de cache e refresh das miniaturas na UI. |

Todos os atributos e relacionamentos anteriores (`id`, `title`, `content`, `pdfData`, `pageCount`, `gridStyle`, `gridSpacing`, `gridOriginX`, `gridOriginY`, `notebook`, `strokes`, `shapes`) permaneceram inalterados. O atributo `emoji` não foi adicionado nesta etapa (escopo reservado para FEAT-02).

A migração foi comprovada em `NoteCoverTests.testLegacySQLiteStoreMigratesAndPreservesAllEntities` criando um banco SQLite temporário com a cópia exata do `NSManagedObjectModel` da base `715f26d` (sem os campos de capa), populando `Notebook`, `Note` de texto, `Note` com PDF importado, `Stroke` e `ShapeObject`, verificando que a metadata pré-migração era incompatível com o modelo atual, reabrindo o mesmo arquivo com `TestSupport.makeSQLiteContainer(at:)`, validando a preservação integral de todas as entidades com campos de capa inicialmente `nil` e aplicando uma nova capa PNG seguida de nova reabertura do SQLite.

## Arquitetura de mídia de capa e extensão futura para GIF

A camada de mídia em `Easy Notes/Models/NoteCoverMedia.swift` separa validação, classificação, cache e renderização:

- `NoteCoverMediaKind`: classifica mídias em `.staticImage` ou `.animatedGIF` exclusivamente a partir do tipo real detectado pelo ImageIO (`CGImageSourceGetType` / `UTType`), sem que um hint de extensão divergente sobrescreva bytes reais.
- `NoteCoverMedia.validated(data:contentType:)`: valida via `CGImageSourceCreateWithData` que os bytes decodificam uma imagem real (`CGImageSourceGetCount > 0`, `CGImageSourceCreateImageAtIndex(source, 0, nil)` com dimensões positivas e conformidade a `UTType.image`, rejeitando PDFs, texto ou bytes corrompidos).
- `NoteCoverCache`: cache LRU limitado (capacidade padrão de 128 entradas) e *thread-safe* via `NSLock`, indexando chaves por `noteID` e `EntryKind` (`.customCover` e `.pdfFallback`) para que `invalidate(noteID:)` e a evicção LRU limpem entradas e chaves de rastreamento sem vazamentos ou dependência de retenção não determinística do `NSCache`.
- `NoteCoverMediaRendering` e `NoteCoverRendererRegistry`: marcados explicitamente com `@MainActor`, despacham a renderização por `NoteCoverMediaKind` para `NoteCoverView`. Hoje, `StaticImageCoverRenderer` atende `.staticImage` e também atua como fallback seguro (quadro 0) para `.animatedGIF`.

Para habilitar reprodução animada de GIF em uma etapa futura sem alterar Core Data, `NoteViewModel` ou `NoteCardView`/`NoteListRowCardView`, basta implementar `AnimatedGIFCoverRenderer: NoteCoverMediaRendering` retornando `.view(AnyView(...))` e registrá-lo na inicialização do app:

```swift
NoteCoverRendererRegistry.shared.register(
    AnimatedGIFCoverRenderer(),
    for: .animatedGIF
)
```

Como `NoteCoverView` inclui o tipo concreto do renderer na chave de cache e só armazena resultados `.image(NSImage)` no `NoteCoverCache`, um renderer que retorne `.view(...)` assume imediatamente a exibição animada sem conflitar com o cache estático.

## Contrato para FEAT-02

O menu definitivo de nome, emoji e capa da FEAT-02 deve consumir os seguintes contratos na fila principal do `NoteViewModel`:

- **Aplicar capa via URL** (painel ou arquivo local):
  `try viewModel.setCover(for: note, from: url)`
- **Aplicar capa via bytes em memória** (ex.: imagem gerada ou selecionada):
  `try viewModel.setCover(for: note, data: data, contentType: utType)`
- **Remover capa e restaurar o fallback padrão** (primeira página do PDF + prévia de texto + traços):
  `try viewModel.removeCover(for: note)`
- **Leitura de estado na nota**:
  - `note.hasCustomCover`: `true` quando há `coverMediaData` não vazio.
  - `note.coverMedia`: retorna `NoteCoverMedia?` (`data`, `contentTypeIdentifier`, `kind`).
- **Garantias e erros (`NoteCoverError`)**:
  - Exige `note.managedObjectContext === context && !note.isDeleted`; caso contrário lança `.invalidNote`.
  - Valida os bytes com `NoteCoverMedia.validated(...)` antes de mutar qualquer campo da nota, lançando `.unreadableImage` ou `.unsupportedMediaType(String)` com preservação total da capa anterior.
  - Em falha de `context.save()`, reverte `coverMediaData`, `coverMediaType`, `coverUpdatedAt` e `updatedAt` e lança `.persistenceFailed(String)`.
  - Nunca modifica `title`, `content`, `pdfData`, `strokes` ou `shapes`.
  - Em caso de sucesso na troca ou remoção, invalida `coverCache` para `note.id` e chama `loadNotes()`.

Na interface de biblioteca (`NotesView.swift`), enquanto a FEAT-02 não entra, o menu de contexto dos cartões fora da lixeira expõe as ações provisórias **"Escolher capa…"** (ou **"Trocar capa…"**) e **"Remover capa"**, utilizando `NSOpenPanel` com `NoteCoverMedia.supportedStaticImageTypes` e exibindo alerta em caso de arquivo inválido sem perder a capa anterior.

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
- Suíte XCTest (`EasyNotesTests`): **36 testes executados, 0 falhas** (`NoteCoverTests`: 5, `NoteViewModelTests`: 14, `PDFExportTests`: 8, `PenColorTests`: 4, `ShapeObjectTests`: 5).
- Sem avisos de ambiguidade de entidades Core Data durante os testes de migração ou persistência.

## Ajustes pós-revisão (`051192a`)

- Substituído o `NSCache` sem delegate de `NoteCoverCache` por cache LRU limitado (`capacity = 128`) protegido por `NSLock`, garantindo retenção determinística e remoção limpa de `keysByNoteID` tanto na evicção LRU quanto na invalidação.
- Removida a sobrescrita de classificação GIF pelo hint `contentType`: somente o formato real decodificado pelo ImageIO define `.animatedGIF` vs `.staticImage`.
- Explicitado `@MainActor` em `NoteCoverRenderedContent`, `NoteCoverMediaRendering`, `StaticImageCoverRenderer` e `NoteCoverRendererRegistry`, e `@unchecked Sendable` com `NSLock` em `NoteCoverCache`.
- Propagado `viewModel.coverCache` por `NotesView`, `NoteCardView`, `NoteListRowCardView` e `NoteThumbnailView` (eliminando uso implícito de `.shared`), isolado o cache em `TestSupport.makeInMemoryViewModel()`, antecipada a validação de tipo não-imagem em `setCover(for:from:)` antes da leitura de disco e ampliada a cobertura de rollback/migração/evicção LRU em `NoteCoverTests`.

## Limitações conhecidas

- A interação física com o `NSOpenPanel` e cliques visuais no menu de contexto da grade/lista foram verificados por compilação e revisão de código; os testes automatizados exercitam o contrato completo de validação, persistência, rollback, invalidação de cache e migração SQLite em nível de modelo e `NoteViewModel`.
- O formato GIF já é validado, persistido e classificado como `.animatedGIF`, mas nesta entrega exibe apenas o quadro 0 via `StaticImageCoverRenderer`; a reprodução animada contínua fica reservada para um futuro `AnimatedGIFCoverRenderer`.
- As ações **"Escolher capa…"** / **"Trocar capa…"** e **"Remover capa"** no menu de contexto são provisórias até a entrega da FEAT-02.
