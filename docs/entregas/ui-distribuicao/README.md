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
