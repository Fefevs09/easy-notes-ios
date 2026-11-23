# Fix 01 — mira e prévia de formas

## Objetivo

Permitir posicionar e reconhecer linhas, setas, retângulos e elipses durante o arraste, sobre papel branco ou PDFs com conteúdo de luminosidade variável.

## Investigação e decisões

- `NoteViewModel.createBlankPDF` preenche a caixa da página com branco opaco. Documentos importados fornecem sua própria imagem de fundo. `PDFView.backgroundColor` colore a área externa à folha. A cor dinâmica de texto usada pela mira podia ficar branca no modo escuro.
- A mira tem núcleo preto sobre páginas claras e branco sobre páginas escuras, com aro da cor oposta. A primeira consulta renderiza o PDF base em 16 × 16 amostras de cinza. A maioria dessas amostras determina a polaridade por página, guardada em cache com chave fraca. Nas regiões de luminosidade diferente da maioria, o aro fornece contraste local.
- O overlay desenha a linha da cor escolhida e sobrepõe pontos com núcleo preto e aro branco. O tracejado com extremidades redondas segue o mesmo CGPath da forma final, inclusive os dois subcaminhos da cabeça da seta. O intervalo normal é de dez pontos de tela. Em zoom baixo, cada extremidade da cabeça curta recebe uma marca extra, preservando o espaçamento e o diâmetro dos pontos da haste.

## Contratos

A prévia existe apenas durante a criação. O desenho usa coordenadas de página e compensa o zoom no tamanho e espaçamento das marcas. A mira conserva seu tamanho e hotspot. O fluxo de eventos, foco, atalhos, árvore de acessibilidade e seleção permanece o existente. O mouse-up descarta deslocamentos inferiores a três pontos de página. Core Data armazena apenas os pontos de controle originais. A exportação usa o caminho sólido da forma.

## Progresso e pendências

A implementação foi integrada sobre origin/main em 3c39b62, isolada da outra feature presente no checkout principal. O código de produção foi encaminhado à revisão no commit 3fa51f9. A primeira tentativa de revisão parou por limite de uso. A segunda, com GPT-6.2 Sol em esforço baixo, identificou encolhimento dos pontos na seta com zoom baixo. A correção mantém a escala dos pontos e cobre a haste da seta nos três níveis de zoom. A revisão confirmou o isolamento da exportação e destacou que a polaridade é por folha, com aro para conteúdo misto.

Xcode 27.2, scheme Easy Notes, destino macOS. A base passou em 44 testes. O candidato passou em build e 47 testes, inclusive polaridade em duas páginas de PDF, pontos a 25%, 100% e 400% e asas da seta. Comando de reprodução:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS' build test
```

Pendente de conferência humana: sensação do arraste em PDF importado com conteúdo misto, aparência clara e escura, navegação por teclado e VoiceOver em sessão gráfica.
