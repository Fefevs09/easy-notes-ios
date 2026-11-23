# Easy Notes

## Produto

Aplicativo nativo para macOS para escrever, desenhar e anotar PDFs. A biblioteca organiza notas em cadernos e oferece busca e visualização em grade ou lista. No editor, a página fica no centro, com ferramentas de escrita e desenho acima e painéis laterais para papel, páginas e anotações.

## Público e voz

Estudantes e profissionais. A interface usa português do Brasil e um tom direto e discreto. Os rótulos indicam a ação em poucas palavras, como “Importar PDF”, “Caneta” e “Ajustar à largura”.

## Clima

Calmo, editorial e descontraído. O papel branco, os fundos quentes e o violeta nos controles ativos compõem a interface atual. Evitar um ar excessivamente sério ou solene.

## Marca

Fonte do sistema de design: [Easy Notes/PixelTheme.swift](<Easy Notes/PixelTheme.swift>).

A marca combina o ícone de caderno violeta e o nome “easy notes” em minúsculas. O tema usa tipografia monoespaçada nos destaques e a fonte do sistema nos controles. Cartões, painéis e estados ativos compartilham estilos definidos no tema.

## Referências

- [Samsung Notes](https://www.samsung.com/br/apps/samsung-notes/) como referência de experiência de uso. Aproveitar os três fluxos confirmados: começar a escrever rapidamente, organizar notas em pastas ou cadernos e escrever diretamente sobre PDFs.
- Interface atual do Easy Notes como referência visual. A captura do editor mostrou o PDF ao centro, os ajustes de papel à esquerda, as anotações à direita e os controles de página e zoom no rodapé.

## Restrições

- Aplicativo nativo para macOS, com interface em SwiftUI e AppKit.
- O código atual fixa o tema claro.
- No editor de PDF, as anotações ficam em uma camada que preserva o documento original.

## Registro de decisões

- 2026-11-19 — Estudantes e profissionais são o público principal.
- 2026-11-19 — A interface adota voz direta e discreta e uma direção visual calma, editorial e descontraída.
- 2026-11-19 — O Samsung Notes é referência para escrita rápida, organização de notas e anotação sobre PDFs.

- 2026-11-23 — Nos cartões da grade com capa personalizada, a imagem ocupa toda a superfície. A legenda branca fica sobre um degradê escuro no rodapé e as ações ficam no canto superior direito (opção A).

## Questões em aberto

- Há algum aspecto da experiência do Samsung Notes que deve ser evitado?
- Existe outra referência externa que valha incluir?
- Quais requisitos de acessibilidade devem orientar o design? Há demanda por tema escuro?
