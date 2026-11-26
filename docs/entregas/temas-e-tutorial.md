# Temas e tutorial contextual

Plano aprovado. Base inicial observada: `origin/main` em `49aa070`.

## Objetivos e contratos

- Temas: adicionar Lavanda, Grafite e Framboesa ao seletor de Ajustes. Preservar os identificadores e a seleção padrão; oferecer variantes claras e escuras dos tokens de destaque.
- Tutorial: após Começar, apresentar cadernos, busca, nova nota e ferramentas do editor. Exibir uma etapa por vez quando a âncora estiver disponível. Persistir o andamento e o encerramento em preferências locais. Preservar o fluxo das instalações existentes.
- As duas entregas usam os tokens semânticos de `PixelTheme`. Cores documentais e persistência Core Data ficam fora do escopo.

## Andamento

| Entrega | Branch | Thread | Estado |
| --- | --- | --- | --- |
| Temas | `feat/novos-temas` | [feat-01 · Temas](t3-thread://v2/71cda6a1-8462-4f09-a68d-a023a4482c84/mcp:launch:604a2b222f0552a8ae4c0030d11346eb4f1e288cdb1426ff308158ee3ce512df) | [PR #20](https://github.com/Fefevs09/easy-notes-ios/pull/20) aberto para aprovação humana |
| Tutorial | `feat/tutorial-contextual` | [feat-02 · Tutorial contextual](t3-thread://v2/71cda6a1-8462-4f09-a68d-a023a4482c84/mcp:launch:193ab70802f05be39730f621d4fa541f60c71a5e0b394c9cc1bf4bc53599165c) | Implementado, revisão independente em andamento |

## Revisão e validação

O coordenador acompanha a implementação e registra os SHAs. Um revisor independente verifica cada SHA. O Operator compila e testa cada branch e a combinação em worktrees isolados. A abertura dos PRs precede a aprovação humana exigida para merge em main.

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
derived_data=$(mktemp -d)
args=(-project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data")
xcodebuild "${args[@]}" build
xcodebuild "${args[@]}" -parallel-testing-enabled NO test
```

Xcode 27.2 confirmado.

- Temas: implementação em `1e8067f`. A revisão independente encontrou problemas de contraste em Nova nota, Salvar e no contador de caderno ativo. Ajustados em `66ed6a0` e `865dd5f`. Build Debug aprovado e a suíte no último commit de código passou com 83 testes. Conferência visual dos cartões pendente.
- Tutorial: `98e52b5`, com 84 testes aprovados no Xcode. A biblioteca demonstrativa existente é preservada. Escape, retomada e foco foram exercitados em etapas isoladas. Validação manual do fluxo completo e leitura falada pelo VoiceOver pendentes.
- Integração preliminar: `865dd5f` + `98e52b5` combinaram sem conflito, com build Debug aprovado e 86 testes passando no Xcode 27.2. Após as aprovações e os merges, repetir a suíte em `main`.

## Roteiro de validação manual

1. Em Ajustes → Aparência, selecione Lavanda, Grafite e Framboesa em Claro e Escuro. Confira o rótulo de Nova nota, o botão Salvar ao renomear e o contador no filtro de cadernos. Relance o app e confirme a seleção.
2. Em uma instalação isolada, abra o app e pressione Começar. Percorra as dicas da biblioteca. Abra uma nota para acessar a dica do editor. Teste Escape, Retomar tutorial, Pular tutorial e Concluir, em execuções separadas.
3. Na mesma instalação isolada, alterne entre teclado, mouse e VoiceOver. Verifique as etapas com barra lateral recolhida, controles fora da tela e uma segunda janela. Relance no meio do tutorial e após finalizar.
4. Em uma cópia de biblioteca já existente, abra a versão nova e confirme que ela mostra diretamente as notas e os cadernos da instalação.
