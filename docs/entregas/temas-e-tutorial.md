# Temas e tutorial contextual

Plano aprovado. Base inicial observada: `origin/main` em `49aa070` (atualizada para `b5f0655` após merge do PR #20).

## Objetivos e contratos

- Temas: adicionar Lavanda, Grafite e Framboesa ao seletor de Ajustes. Preservar os identificadores e a seleção padrão; oferecer variantes claras e escuras dos tokens de destaque.
- Tutorial: após Começar, apresentar cadernos, busca, nova nota e ferramentas do editor. Exibir uma etapa por vez quando a âncora estiver disponível. Persistir o andamento e o encerramento em preferências locais. Preservar o fluxo das instalações existentes.
- As duas entregas usam os tokens semânticos de `PixelTheme`. Cores documentais e persistência Core Data ficam fora do escopo.

## Andamento

| Entrega | Branch | Thread | Estado |
| --- | --- | --- | --- |
| Temas | `feat/novos-temas` | [feat-01 · Temas](t3-thread://v2/71cda6a1-8462-4f09-a68d-a023a4482c84/mcp:launch:604a2b222f0552a8ae4c0030d11346eb4f1e288cdb1426ff308158ee3ce512df) | [PR #20](https://github.com/Fefevs09/easy-notes-ios/pull/20) **merged em `main`** (`b5f0655`) |
| Tutorial | `feat/tutorial-contextual` | [feat-02 · Tutorial contextual](t3-thread://v2/71cda6a1-8462-4f09-a68d-a023a4482c84/mcp:launch:193ab70802f05be39730f621d4fa541f60c71a5e0b394c9cc1bf4bc53599165c) | [PR #21](https://github.com/Fefevs09/easy-notes-ios/pull/21) **pronto para aprovação humana** |

## Revisão e validação

O coordenador (Gemini 4 Neon) planeja e acompanha a integração; a execução, revisão independente e validação integrada são delegadas ao Gemini 4 Hydrogen em worktrees isolados. A abertura dos PRs precede a aprovação humana exigida para merge em `main`.

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
derived_data=$(mktemp -d)
args=(-project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' -destination 'platform=macOS,arch=arm64' -derivedDataPath "$derived_data")
xcodebuild "${args[@]}" build
xcodebuild "${args[@]}" -parallel-testing-enabled NO test
```

Xcode 27.2 confirmado.

- **Temas (`feat-01`):** implementação em `1e8067f`. Revisão independente encontrou problemas de contraste em Nova nota, Salvar e no contador de caderno ativo; corrigidos em `66ed6a0` e `865dd5f`. Build Debug aprovado e 83 testes passando. PR #20 já integrado em `main` (`b5f0655`).
- **Tutorial (`feat-02`):**
  - Implementação inicial em `98e52b5` (84 testes).
  - 1ª revisão independente identificou 3 P2 (disputa de foco na apresentação automática, restauração de foco no Escape, abertura de qualquer nota consumindo etapa **Nova nota**) e 1 P3 (rodapé oferecendo **Avançar** com âncora indisponível). Todos corrigidos em `d40e4a1` (88 testes, 0 falhas).
  - 2ª revisão independente em `d40e4a1` validou os 4 ajustes e apontou 2 casos de borda P3 (`focusResume` ao perder âncora e `pendingTipFocusStep` ao desativar a janela durante os 250 ms), corrigidos na sequência com 88 testes passando (13 em `WelcomeStateTests`, 0 falhas).
- **Integração conjunta (`origin/main` `b5f0655` + `feat/tutorial-contextual` `d40e4a1`):** merge limpo (0 conflitos), build Debug aprovado e **90 testes passando (0 falhas)** no Xcode 27.2. Após aprovação e merge do PR #21 em `main`, repetir a suíte em `main`.

## Roteiro de validação manual (pendente de conferência interativa em GUI/VoiceOver)

1. Em Ajustes → Aparência, selecione Lavanda, Grafite e Framboesa em Claro e Escuro. Confira o rótulo de Nova nota, o botão Salvar ao renomear e o contador no filtro de cadernos. Relance o app e confirme a seleção.
2. Em uma instalação isolada, abra o app e pressione Começar. Percorra as dicas da biblioteca. Abra uma nota via **Nova nota** para acessar a dica do editor. Teste `Escape`, `Retomar tutorial`, `Pular tutorial` e `Concluir`, em execuções separadas.
3. Na mesma instalação isolada, alterne entre teclado, mouse e VoiceOver. Confirme que a exibição automática após 250 ms não rouba foco de `⌘K` ou do editor, que `Escape` devolve foco à âncora (ou a `Retomar tutorial` como fallback quando disponível) e que o rodapé se adapta na Lixeira, com barra lateral recolhida, controles fora da tela e em uma segunda janela. Relance no meio do tutorial e após finalizar.
4. Em uma cópia de biblioteca já existente, abra a versão nova e confirme que ela mostra diretamente as notas e os cadernos da instalação.
