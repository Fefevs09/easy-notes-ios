# Feat-02 — Sensibilidade à pressão

## Objetivo

Variar a espessura da Caneta Tinteiro com a pressão da mesa digitalizadora no editor macOS. A preferência **Ajustes → Canetas e Cores → Sensibilidade à pressão** começa desligada, é persistida pelo `AppSettingsStore` e volta ao padrão com **Restaurar padrões**.

## Contratos e decisões

- A preferência é lida no início do gesto. Só a Caneta Tinteiro em um evento de mouse com subtipo `tabletPoint` e pressão inicial positiva inicia captura. A amostra pode vir do campo de pressão da mesa em Core Graphics ou de `NSEvent.pressure` num evento identificado como de mesa. Mouse, trackpad e gestos sem uma amostra inicial utilizável usam largura constante. Uma vez confirmada a mesa, amostras ausentes conservam a última pressão conhecida e eventos nativos do mesmo dispositivo podem atualizar a pressão com a ponta parada. A liberação encerra o gesto.
- `Stroke.points` preserva os tokens `x,y` e ganha um sufixo opcional `;pressure-v1:p1|p2|…`. O sufixo é gravado junto do traço e contém um valor normalizado por ponto. Leitores anteriores ignoram esse token sem vírgula e continuam lendo todas as coordenadas. Ausência, versão desconhecida ou conteúdo inválido produz traço constante a partir de `Stroke.width`. O schema Core Data e `CoreDataStack.swift` são os mesmos da base.
- `FreehandStrokeRenderer` usa `Stroke.width` como espessura nominal. A pressão normalizada mapeia para 25% a 100% dessa espessura, com união de contornos contínuos, pontas redondas e cortes em reversões bruscas num único preenchimento. A mesma geometria atende ao preview, traço reaberto, miniaturas de página e capa e exportação vetorial. A borracha continua usando a linha central e o raio já definidos no editor.

## Integração com imagens

Em `PDFAnnotationCanvasView.swift`, a feat-02 altera `renderStrokes`, a camada de traços em `PageDrawingCanvas.draw`, os handlers de mouse do traço livre e sua serialização. As assinaturas de `renderStrokes(for:pageIndex:into:)` e `deserializeStrokePoints(_:)` continuam válidas. Ao integrar a camada de imagens, preservar a chamada a `renderStrokes` nas superfícies existentes e manter o preview do traço livre após a renderização dos traços persistidos. O patch de pressão dispensa mudanças no modelo programático ou nos serviços de exportação.

## Retomada e verificação

- Branch `t3/pencil-pressure-strokes`, worktree `~/.t3/worktrees/easy-notes-ios/t3-b4e9e938-c77f432c041c167b`, base `origin/main` em `49aa07043df58515cf506b43541375322a90eb21`.
- Xcode 27.2, macOS arm64, DerivedData isolado: 89 testes passaram após as correções da revisão. A suíte cobre preferência, exclusão de pressão de mouse comum, política ao iniciar o gesto, amostras tablet simuladas, round trip SQLite de traços antigos e novos e largura observada nos pixels do PDF. A verificação de um traço de 4.000 pontos inclui a preparação do bitmap e exige conclusão em menos de 1 segundo.
- Na validação manual, usar uma mesa digitalizadora e um armazenamento de teste para conferir os eventos do driver, o toggle via teclado/VoiceOver e a aparência durante gestos com zoom. A captura em hardware físico ainda está pendente.

```sh
test_dir=$(mktemp -d /tmp/easy-notes-feat02.XXXXXX)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$test_dir/DerivedData" -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```
