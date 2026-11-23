# FIX-01 · Título da nota e nome do PDF

## Reprodução na base f269874

Um XCTest diagnóstico temporário criou duas notas no mesmo caderno em um store em memória. A primeira continha o texto “Texto”. A segunda foi importada de um PDF de uma página criado em uma pasta temporária exclusiva. O teste avaliou as expressões usadas pelos dois painéis com uma edição digitada e a gravação de 500 ms ainda pendente.

| Origem | Título armazenado | Campo do editor | Sugestão de Compartilhar | Sugestão do menu |
| --- | --- | --- | --- | --- |
| Nota comum | Comum | Comum editada | Comum editada.pdf | Comum.pdf |
| Origem.pdf | Origem | Origem editada | Origem editada.pdf | Origem.pdf |

As duas asserções de igualdade falharam. Ao executar a gravação usada na saída do editor e reler os objetos, os títulos editados e o vínculo com o caderno estavam corretos. O arquivo Origem.pdf continuava legível no caminho inicial e com os bytes importados. A divergência observada ocorreu na sugestão de exportação durante a edição.

## Contrato para FEAT-02

Capture a nota do item ao abrir o menu. Ao confirmar, chame `try viewModel.renameNote(note, to: novoTitulo)` na fila do contexto da interface. Cancelar descarta o rascunho do menu. A operação recebe o objeto Core Data específico, inclusive quando outra nota está selecionada, e exige que ele pertença ao contexto e esteja disponível. Um título idêntico preserva a data de modificação. Uma alteração grava título e data, atualiza a lista com o filtro e ordenação atuais e propaga erros de gravação ao chamador.

O editor lê o título da nota e salva a cada mudança do campo. Isso implica uma gravação e uma atualização da consulta por mudança de texto. Ao trocar de nota ou encerrar a edição, todas as mudanças já entregues pelo campo foram processadas. Os dois painéis consultam `note.suggestedPDFName`. O título aceita a string fornecida, inclusive vazia, que gera a sugestão “Sem título.pdf”. A importação copia os bytes e usa o nome sem extensão como título inicial por padrão. O usuário escolhe o destino ao exportar.

## Verificação

Build Debug com Xcode 27.2 (27B52) e XCTest no macOS arm64 seguindo os comandos do README desta pasta. Passaram 30 testes, incluindo dois novos. O teste de identidade alterna a seleção, renomeia a nota comum com o PDF selecionado, renomeia o PDF e encerra a edição limpando a seleção. Após resetar o contexto, recupera ambas por objectID, confere título, texto, caderno e PDF importado, e abre as duas exportações de uma página. Os nomes sugeridos após reabrir foram “Comum editada.pdf” e “PDF editado.pdf”. O segundo teste verifica o título vazio e a repetição de uma renomeação.

A reprodução e a regressão exercitaram o modelo e as regras de nome com dados descartáveis. A interação física com o campo, o painel nativo e o encerramento do processo macOS ficaram fora do teste.
