# Preparação das entregas do Easy Notes

Base local validada no worktree isolado da branch `t3/prepare-easy-notes-tests-docs`: `7c187c7` (seletor horizontal de cor da caneta). Na preparação, `origin/main` apontava para `e522bd6`. O PR para main inclui o commit do seletor como dependência. Os testes de cor exercitam esse código.

## Matriz de implementação

| Ordem | Entrega | Contrato e critério de aceite |
| --- | --- | --- |
| 1A | FEAT-01 · Formas | Usar `ShapeKind.drawable` como fonte das opções de desenho (reta, retângulo, elipse e seta). Conferir que selecionar cada opção ativa a ferramenta e que o desenho mantém tipo e página após salvar, reabrir e exportar. |
| 1B, em paralelo com 1A | FIX-01 · Título e arquivo | Reproduzir com uma nota nova e um PDF importado. Registrar o título armazenado, o nome do arquivo de origem e o nome sugerido na exportação antes e depois de renomear e reabrir. Hoje a importação usa o nome sem extensão quando não recebe título, e a exportação sugere o título seguido de .pdf. Determinar onde divergem e estabelecer uma operação de rename por nota que preserve o conteúdo, o PDF e o arquivo de origem. |
| 2 | FEAT-03 · Capas | Definir a representação persistida da capa e o fallback para a prévia da primeira página, com placeholder quando indisponível. Validar troca, remoção, atualização do cache e reabertura. Usar um store SQLite temporário criado com o modelo anterior para verificar compatibilidade Core Data e preservação de notas, PDFs e desenhos. |
| 3, depende de FIX-01 e FEAT-03 | FEAT-02 · Menu de nome e emoji | Aplicar o nome pela operação de rename e o emoji pelo contrato de capa. Validar cancelamento, edição da nota correta e atualização na lista após salvar e reabrir. |

## Baseline macOS

Em 23/11/2026, Xcode 27.2 (27B52), macOS 27.2.1 arm64. O build Debug do aplicativo passou. O scheme compartilhado executou 28 XCTest com zero falhas: 11 de NoteViewModel, 8 de exportação PDF, 4 de cor e 5 de formas.

O bundle de testes compila as fontes do app sem o ponto de entrada SwiftUI e roda no processo xctest. Cada caso usa um store Core Data em memória. A primeira execução passou nas asserções, mas registrou entidades ambíguas porque a fixture recriava o modelo a cada caso. O harness agora compartilha a definição de modelo da aplicação e cria um contexto independente para cada teste. A execução final passou sem aqueles erros. O log ainda contém diagnósticos do Xcode e AppIntents e uma mensagem do CoreGraphics ao ler a fixture PDF mínima.

Para reproduzir em um Mac arm64, na raiz do projeto com zsh:

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
derived_data=$(mktemp -d)
args=(-project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data")
xcodebuild "${args[@]}" build
xcodebuild "${args[@]}" -parallel-testing-enabled NO test
```

As quatro entregas da matriz seguem pendentes. A suíte atual cobre operações de modelo, desenho e exportação. A reprodução do problema de título, a migração de um store legado e a interação com o futuro menu fazem parte das respectivas entregas.
