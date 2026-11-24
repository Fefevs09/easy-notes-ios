# Cor do papel quadriculado, pautado e pontilhado

Em **Configurações da nota → Papel**, escolha um dos três papéis com marcações. O seletor **Cor da grade** aceita uma cor personalizada. Para editar pelo teclado, navegue até **Hexadecimal**, digite seis dígitos sRGB e pressione Return. O campo aceita o prefixo `#` e restaura o valor salvo se a entrada for inválida. Os controles têm rótulos de acessibilidade em português.

O papel liso oculta os controles e conserva a última escolha para quando as marcações forem reativadas. O editor, as miniaturas da biblioteca e das páginas e o PDF exportado usam a cor da nota com opacidade de 16%. Todas as linhas do quadriculado têm 0,5 ponto, inclusive as que passam pela origem. O espaçamento e a posição da origem continuam vindo da nota. A prévia de criação usa o preto padrão.

## Persistência e integração

O modelo programático acrescenta apenas o atributo opcional `Note.gridColorHex`. Ao abrir uma nota sem valor, o renderizador usa preto sRGB `#000000`. A escolha explícita é gravada em `#RRGGBB`. A migração leve continua sob responsabilidade do Core Data, com os mesmos ajustes de inferência do projeto.

A base já inclui `Notebook.colorIndex` e os relacionamentos de pastas. Ao integrar a fix-02, mantenha os atributos de ambas as entidades em `CoreDataStack.makeModel()`. Execute novamente os testes SQLite com o modelo combinado.

## Verificação

O scheme **Easy Notes** foi compilado e testado no macOS com Xcode em `/Applications/Xcode.app/Contents/Developer`, DerivedData temporário e contextos em memória ou SQLite temporário. Os testes cobrem migração de modelos anteriores à capa, ao emoji, à hierarquia de cadernos e à cor da grade. Verificam também a cor após reabertura, a igualdade dos pixels nas linhas centrais e adjacentes e a presença da tinta escolhida nas duas miniaturas e no PDF exportado.

A navegação interativa por teclado e a leitura dos controles pelo VoiceOver ficaram sem validação manual.
