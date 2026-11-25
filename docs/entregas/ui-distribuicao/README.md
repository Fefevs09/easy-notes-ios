# Interface e distribuição do Easy Notes

Plano aprovado em 24/11/2026. Base de planejamento `7be24c4`. A coordenação mantém este índice. Cada implementação e revisão opera em checkout próprio.

| Entrega | Contrato e dependências | Estado inicial |
| --- | --- | --- |
| fix-01 | Três ícones na seleção de canetas. Preservar ToolType, foco, tooltip, seleção e nome acessível. | Em execução em t3/replace-pen-subtype-labels. |
| fix-02 | Catálogo do app reproduz o caderno de EasyNotesBrandMark sem o nome. Validar tamanho mínimo e bundle. | Em execução em t3/match-app-icon-brand-mark. |
| feat-01 | Boas-vindas em português com ação Começar. Reconhecer instalação nova antes de inicializar conteúdo, preservar bases existentes e coordenar janelas. | A iniciar após liberação de uma frente. |
| feat-02 | Empacotar build Release em DMG, verificar a imagem montada e distribuir com SHA-256. Publicar o commit integrado após os merges. | A iniciar após liberação de uma frente. |

## Continuidade

Cada entrega tem registro próprio neste diretório com decisões, testes e pendências. Para retomar, confira o head do PR e a revisão desse commit antes de integrar. O coordenador acumula pesquisa e memória. Implementadores registram as evidências. Cada revisão é delegada separadamente. Aprovação humana e checks aplicáveis precedem o merge na main.

Usar Xcode em /Applications/Xcode.app com DEVELOPER_DIR por comando e DerivedData isolado. O projeto declara macOS 26.2. A máquina reportou zero identidades válidas de assinatura. Confirmar assinatura de distribuição e notarização antes de descrever o status da release. Não usar o banco pessoal para testar abertura do pacote ou migração.

## Validação da base

Xcode 27.2, macOS 27.2.1 arm64, esquema Easy Notes. Build Debug concluído e 75 testes passaram, zero falhas. Resultado local em /tmp/easy-notes-baseline.XwF8cJ/test.xcresult. A assinatura de distribuição não fez parte deste teste.

## Progresso

- fix-01 foi publicado no PR [#17](https://github.com/Fefevs09/easy-notes-ios/pull/17), commit 5e1a8605917979a3a824fb791ea1d4bed1c4dfcf. O implementador registrou build e 75 testes aprovados. Revisão independente iniciada.
- feat-01 foi delegado em worktree próprio. Verificar a primeira abertura, a atualização e o comportamento entre janelas.
- fix-02 foi publicado no PR [#16](https://github.com/Fefevs09/easy-notes-ios/pull/16), commit 65b8fb2777af011c66a7517e1251285c5570e199. O implementador verificou os ícones de 16 e 32 px no pacote compilado e registrou 75 testes aprovados. Revisão independente iniciada.
- feat-02 está em implementação. O pacote de teste local antecede a compilação de distribuição a partir da main integrada.
- Revisão independente do PR #16 concluída sobre 65b8fb2, sem bloqueadores. O revisor confirmou as dez representações macOS compiladas, as variantes do catálogo e a correspondência com a marca da biblioteca. O renderizador usado na validação é temporário. O Capy comentou nos PRs #16 e #17 sem solicitar ajustes. Ambos aguardam aprovação humana.
- Revisão independente do PR #17 concluída no commit 5e1a860, sem bloqueadores. O revisor compilou o commit e verificou os três estados visuais, seleção de Lápis por clique e a árvore AX com descrições e ajuda em português e seleção apenas no botão ativo. O ensaio ocorreu em janela isolada. Tab/Espaço, tooltip por hover e anúncio audível pelo VoiceOver seguem pendentes.
- feat-02 está no PR [#18](https://github.com/Fefevs09/easy-notes-ios/pull/18), commit 4bccfb48ec11de2320ca9cf6df350ec0869e4076. Build universal local, 75 testes aprovados e checksum do DMG confirmado pela coordenação. O pacote de teste tem assinatura ad hoc e não foi publicado. Revisão independente em andamento.
- feat-01 está no PR [#19](https://github.com/Fefevs09/easy-notes-ios/pull/19), commit 6a2d7ce5e5b23d5f9709247602c34f0d7029eb32, com build e 80 testes aprovados. Revisão independente iniciada. A interação manual entre janelas, por teclado e por VoiceOver está pendente.
- A coordenação corrigiu os dois achados do revisor no PR #18 (f528d93), validando a publicação atômica do DMG e do checksum e a preservação do ID da notarização com falhas injetadas. O comentário seguinte do Capy cita um achado adicional cujo conteúdo não foi disponibilizado no GitHub.
- O usuário aprovou o PR #19 no chat para o commit 6a2d7ce. O Capy comentou sem apontamentos, o GitHub informa mergeável e não há checks ou comentários de linha. Integrar após o resultado da revisão independente, se não houver bloqueadores.
- PR #19 integrado na main após a correção 7f89137. O revisor confirmou clique e Return em duas janelas isoladas e apontou o caso de pasta personalizada gravável sem SQLite. A correção inclui teste de regressão e passou na compilação final com 81 testes e zero falhas.
- PR #18 aprovado pelo usuário e integrado na main em 53f4852. A ancestralidade do commit de empacotamento f528d93 foi confirmada no remoto. PRs #16 e #17 ainda aguardam aprovação para compor o DMG final.

## Resultado final

As quatro entregas foram integradas na main. O PR #16 entrou em 7ebe8b0 e o PR #17 em 29f3830. A árvore integrada passou nos 81 testes do Xcode. A pré-release [Easy Notes 1.0, build 1](https://github.com/Fefevs09/easy-notes-ios/releases/tag/v1.0-build.1-preview.1) usa o commit 29f3830, macOS 26.2+ e as arquiteturas arm64 e x86_64. A imagem montada passou nas verificações de integridade, e o download público produziu SHA-256 8f9c2b8fe8b8756c5fcd411e8c2beca245cecc527903f0b9cb4f4616ee323c1a.

O app distribuído para teste usa assinatura ad hoc. Assinatura Developer ID, notarização e abertura da cópia baixada em ambiente isolado nas duas arquiteturas seguem pendentes para a distribuição estável.
