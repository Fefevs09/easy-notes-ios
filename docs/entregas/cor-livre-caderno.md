# FIX-02 · Cor livre do caderno

Em **Editar caderno…**, o seletor nativo do macOS abre com a cor atual. A escolha fica no rascunho da janela até **Salvar**. **Cancelar** descarta as mudanças de nome e cor.

O atributo opcional `Notebook.colorHex` armazena sRGB opaco em `#RRGGBB`. A barra lateral, os filtros, as linhas e o menu **Mover para…** usam a mesma cor. Para o fundo dos cartões, o tema mistura 20% da cor com 80% de branco. Os cartões com capa personalizada continuam exibindo a imagem.

A migração leve do SQLite mantém o índice de paleta anterior. Na ausência de um hexadecimal válido, o tema usa esse índice e seu tom de cartão original. Se o índice também estiver ausente ou fora da paleta, o nome determina a cor. Ao renomear, o índice é fixado antes da troca do nome. A alteração de esquema fica na entidade `Notebook`, permitindo que FIX-01 adicione a cor da grade na entidade `Note` de forma independente.

## Validação

O teste `testFreeColorSurvivesMigrationAndReopen` cria um SQLite temporário com o esquema imediatamente anterior, confere a cor legada, renomeia o caderno, grava uma cor fora da paleta e abre outro contêiner para verificar a identidade e a cor. Também verifica o destino no menu e a recuperação de um hexadecimal inválido.

No Xcode 27.2 (27B52), o build Debug para macOS arm64 passou e os 54 testes passaram com zero falhas. A interação manual com o painel de cores e a execução conjunta com FIX-01 ficaram fora desta validação.
