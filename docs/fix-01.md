# Fix 01 — mira e prévia de formas

## Objetivo

Permitir posicionar e reconhecer linhas, setas, retângulos e elipses durante o arraste, sobre papel branco ou PDFs com conteúdo de luminosidade variável.

## Investigação e decisões

- `NoteViewModel.createBlankPDF` preenche a caixa da página com branco opaco. Documentos importados fornecem sua própria imagem de fundo. `PDFView.backgroundColor` colore a área externa à folha. A cor dinâmica de texto usada pela mira podia ficar branca no modo escuro.
- A mira usa braços e centro pretos com contorno branco. As duas cores coexistem para que partes vizinhas claras e escuras do PDF possam ser atravessadas sem amostrar a página a cada movimento.
- O overlay desenha a linha da cor escolhida e sobrepõe pontos com núcleo preto e aro branco. O tracejado com extremidades redondas segue o mesmo CGPath da forma final, inclusive os dois subcaminhos da cabeça da seta. O intervalo normal é de dez pontos de tela. Em setas pequenas ele diminui para que cada asa receba marcação.

## Contratos

A prévia existe apenas durante a criação. O desenho usa coordenadas de página e compensa o zoom no tamanho e espaçamento das marcas. A mira conserva seu tamanho e hotspot. O fluxo de eventos, foco, atalhos, árvore de acessibilidade e seleção permanece o existente. O mouse-up descarta deslocamentos inferiores a três pontos de página. Core Data armazena apenas os pontos de controle originais. A exportação usa o caminho sólido da forma.

## Progresso e pendências

Implementação e testes de bitmap para espaçamento, contraste e cobertura geométrica concluídos. A sondagem local com Core Graphics confirmou as amostras de linha a 25%, 100% e 400% e a cobertura das demais formas a 100%. A coordenação executará o build e a suíte Xcode no commit entregue. Conferência visual interativa em PDF importado e nos dois modos de aparência segue pendente.
