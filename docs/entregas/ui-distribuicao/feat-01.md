# FEAT-01 · Boas-vindas no primeiro uso

Branch `t3/native-welcome-onboarding` · destino `main`.

## Contrato

- Uma instalação nova abre as boas-vindas em português. A tela usa SwiftUI, `EasyNotesBrandMark`, tipografia e superfícies de `PixelTheme`. **Começar** é a ação padrão da janela e abre a biblioteca. A ação limpa a seleção da nota de exemplo antes de mostrar a lista.
- Todas as janelas principais observam o mesmo estado no app. Enquanto as boas-vindas estão pendentes, cada janela principal exibe a mesma tela. **Começar** em qualquer janela atualiza as demais. A ação é idempotente e novas janelas abrem na biblioteca.
- A preferência local `easyNotes.welcome.status` guarda `pending` ou `completed`. Fechar o app antes de **Começar** mantém a tela pendente, mesmo depois que o Core Data criou o SQLite e gravou exemplos. Restaurar as preferências de aparência e ferramentas preserva a conclusão.
- Para uma preferência ainda ausente, o stack resolve o local de armazenamento pelos mecanismos existentes de caminho e bookmark, verifica o SQLite ativo e o padrão, e só então carrega o armazenamento persistente. Um SQLite anterior, mesmo sem objetos, identifica uma instalação existente. Uma configuração de armazenamento que não pode ser resolvida ou acessada também indica uso anterior, e segue o fallback vigente.
- A identificação consulta a existência do arquivo. O carregamento do Core Data e o preenchimento de bases vazias pelo view model seguem as rotinas existentes. As boas-vindas não alteram o schema nem movem, substituem ou removem os dados da biblioteca.

## Evidência

Testes com suítes de `UserDefaults` exclusivas e diretórios SQLite temporários cobrem a primeira abertura, reabertura antes e depois da conclusão, reset das preferências, observação em duas janelas, SQLite anterior vazio e fallback de configuração indisponível. O teste de migração copia um SQLite real, abre apenas o destino customizado e verifica o arquivo original, os identificadores, o texto e o vínculo da nota com seu caderno.

Build concluído e 80 testes aprovados, com zero falhas. A execução usou Xcode 27.2 (27B52), esquema `Easy Notes`, destino macOS e `DerivedData` isolado.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
derived_data="$(mktemp -d /tmp/easy-notes-welcome.XXXXXX)"
xcodebuild -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' \
  -destination 'platform=macOS' -derivedDataPath "$derived_data" build
xcodebuild -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' \
  -destination 'platform=macOS' -derivedDataPath "$derived_data" \
  -resultBundlePath "$derived_data/tests.xcresult" test
```

A verificação manual da apresentação em duas janelas, foco por teclado e leitura pelo VoiceOver fica pendente para o aceite da interface.

## Revisão e integração

A revisão independente confirmou em duas janelas AppKit isoladas que Return e clique acionam Começar nas duas janelas. Identificou um caso em que mover o SQLite de uma pasta personalizada gravável fazia uma instalação antiga exibir boas-vindas. A detecção passou a reconhecer a preferência de armazenamento resolvida antes da abertura do SQLite. A construção do banco segue o comportamento anterior. O teste de regressão usa pasta e preferências temporárias.

A compilação final com Xcode 27.2 passou com 81 testes e zero falhas. A leitura pelo VoiceOver, Tab/Espaço, bookmarks sob sandbox e a abertura de novas janelas no app distribuído seguem pendentes.
