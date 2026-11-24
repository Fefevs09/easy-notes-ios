# FIX-03 — Páginas na lateral do editor

Ao abrir uma nota de uma ou várias páginas com a lateral visível, o editor apresenta diretamente as miniaturas e o botão de adicionar página. A primeira página começa selecionada. Miniaturas, canvas e rodapé compartilham o índice de seleção. Ocultar e reabrir o painel conserva esse índice e a lista rola até a página selecionada. Trocar de nota volta à página 1.

O botão da barra de ferramentas anuncia “Mostrar painel lateral” ou “Ocultar painel lateral”. A lista mantém os botões nativos para navegação por teclado, o rótulo “Página N” e o traço de acessibilidade de seleção. A engrenagem “Configurações da nota” abre o popover de papel mesmo com a lateral recolhida. Esse popover é o ponto de integração do seletor de grade do FIX-01.

## Validação

Build e testes do esquema `Easy Notes` passaram no macOS com `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, assinatura desativada e DerivedData temporário. O XCTest executou 53 testes com dados descartáveis e zero falhas. A seleção compartilhada, o toggle e os rótulos foram conferidos no código. A interação de ponta a ponta com teclado e VoiceOver ainda precisa de validação manual.
