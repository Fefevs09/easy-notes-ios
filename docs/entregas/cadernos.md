# Cores e subpastas de cadernos

Base de integração `main` em `3c39b62`.

O menu de contexto do caderno oferece **Editar caderno…** para alterar o nome e escolher uma das cinco cores da biblioteca. **Nova subpasta…** cria e seleciona uma pasta dentro do caderno atual. A seta lateral expande e recolhe os filhos. Contadores e filtros continuam mostrando as notas diretamente vinculadas ao caderno.

Os destinos de movimentação usam o UUID para identificar a pasta e exibem o caminho completo, como **Projetos / Ativos**. A barra lateral, os filtros, os cartões, as linhas e o menu de movimentação usam a mesma paleta.

Ao excluir uma pasta, suas subpastas sobem um nível com o conteúdo intacto. As notas diretas passam para Notas Soltas ou, por escolha explícita, para a Lixeira. Uma nota que já estava na Lixeira continua lá.

## Persistência e validação

O modelo Core Data adiciona um índice de cor opcional e relações inversas opcionais entre pai e filhos. A relação entre caderno e notas passa a usar a regra de exclusão nullify. Até a primeira edição, cadernos antigos usam a cor calculada pelo algoritmo original. Ao salvar, o aplicativo grava a cor antes de alterar o nome.

O teste `testMigratingLegacySQLiteAndEditingHierarchy` cria um SQLite temporário com o esquema anterior, fecha o banco e o abre com a migração inferida usada no aplicativo. Confere identidade, conteúdo e vínculo da nota original, cor após renomear, leitura da hierarquia e da cor por outro contêiner, destino do menu e preservação da nota nas duas modalidades de exclusão.

Comando para reproduzir no macOS arm64:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme 'Easy Notes' -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Resultado em 23/11/2026: 45 testes aprovados, zero falhas. A validação foi automatizada, sem inspeção manual da janela.

## Integração com capa e papel

O build Debug e a suíte integrada passaram no Xcode 27.2 em macOS arm64, com 50 testes e zero falhas sobre o código de cee6dee. A revisão identificou destinos com o mesmo caminho visível. O menu agora distingue esses casos e quebra caminhos longos em várias linhas. A revisão independente validou a migração entre processos, mas atingiu o limite de uso antes do parecer final. A inspeção manual com VoiceOver permanece pendente.
