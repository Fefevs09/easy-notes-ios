# FEAT-03 · Modelos de nota no macOS

A folha **Nova nota** oferece **Em branco**, **Calendário mensal** e **Lista de tarefas**. O padrão é **Em branco** e os padrões de papel e orientação continuam vindo dos ajustes. A lista tem caixas desenhadas na página que podem ser marcadas com as ferramentas do editor.

## Contratos

- `NewNoteDraft` leva título, papel, orientação, modelo e, no calendário, mês e ano ao fluxo de criação de `NoteViewModel`. A criação só troca a seleção e fecha a folha após salvar. Um título vazio continua resultando em “Nova Nota”.
- `NoteTemplatePDF` gera uma página vetorial de 612 × 792 pt na vertical ou 792 × 612 pt na horizontal. O calendário usa o calendário gregoriano, com nomes de mês, dias da semana, numeração dos dias e início da semana conforme o locale. O mês e o ano locais são os valores iniciais.
- A prévia desenha a mesma página PDF usada na criação e aplica a camada de papel do editor. Os controles nativos mantêm interação por teclado e mouse. Return confirma, Escape cancela e o rótulo acessível da prévia inclui modelo, papel, orientação e a data do calendário.
- O PDF inicial fica em `Note.pdfData`. Papel e anotações continuam nas camadas existentes. Exportar sem papel preserva o modelo e as anotações. A alteração dispensa migração de Core Data.
- A geração antecede a inserção. Se o contexto rejeitar o salvamento, a criação descarta a inserção da nota e conserva as alterações pendentes de outros objetos. A folha exibe o erro e conserva o rascunho.

## Resultados

- Xcode 27.2 (27B52), esquema **Easy Notes**, macOS arm64, DerivedData separado. A suíte completa passou com **85 testes**, zero falhas e zero testes ignorados.
- Os seis testes de Nova nota cobrem o padrão, papel, orientações, caderno, calendário comum e bissexto, ordem dos dias em diferentes localidades, caixas da lista, anotações e exportação. As falhas de geração e persistência são verificadas com seleção e dados preservados.
- O teste existente de fallback do Core Data recebeu um diretório temporário explícito para a suíte usar armazenamento de teste. A validação manual da folha com mouse, teclado e VoiceOver segue pendente.

## Retomada

Base aprovada `49aa07043df58515cf506b43541375322a90eb21`, branch `t3/add-note-templates`. Para reproduzir os testes com DerivedData isolado, execute a partir da raiz do worktree.

```sh
scratch=$(mktemp -d /tmp/easy-notes-feat03.XXXXXX)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$scratch/DerivedData" -parallel-testing-enabled NO
```

Os testes de criação usam Core Data em memória e exportam para arquivos temporários. A suíte usa fixtures e bancos de teste isolados. Para a validação visual futura, use uma instância com armazenamento de teste e percorra a folha com teclado, mouse e VoiceOver, incluindo fevereiro de 2024, as duas orientações e a tentativa com ano inválido.
