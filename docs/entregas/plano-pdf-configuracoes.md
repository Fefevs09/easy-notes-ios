# Exportação PDF e Configurações — integração

Plano aprovado por Felipe em 24/11/2026. Base comum verificada: `c481d0c`.

| Entrega | Responsável | Contrato |
| --- | --- | --- |
| PDF | EASY-6 | Validar exportação existente contra a nota visível; preservar páginas, grade, formas e traços. Exportar ou cancelar não modifica a nota. |
| Aparência e canetas | EASY-7 | Preferências globais não alteram papel nem conteúdo persistido. Padrões de cor só afetam novos desenhos. Manter escolha manual, opacidade do marca-texto e navegação por teclado. |
| Armazenamento | EASY-7 | Usar cópia consistente, validar conteúdo e acesso persistente; preservar a origem. Nunca substituir biblioteca alheia ou criar biblioteca vazia para mascarar falha de acesso. |

Cada entrega tem um worktree próprio no Mac. EASY-6 não edita preferências nem persistência. EASY-7 não edita o exportador. Se um arquivo de interface se tornar comum, a coordenadora serializa sua integração. Os registros por entrega são `exportacao-pdf.md` e `configuracoes.md` neste diretório.

## Verificação e entrega

- Usar Xcode com `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, DerivedData separado e bibliotecas de teste temporárias. Não usar dados pessoais.
- PDF: abrir o resultado, comparar páginas e anotações, verificar falhas e cancelamento. Não substituir o exportador se já cumprir o contrato.
- Configurações: validar visualmente a janela, teclado, mouse e acessibilidade; exercitar cancelamento, colisão, indisponibilidade e reabertura com dados relacionados.
- Registrar comandos, resultados, limitações e pendências no documento de cada entrega. Não considerar um teste planejado como executado.
- Revisão independente em cada PR; integrar somente o commit aprovado por uma pessoa, com verificações concluídas e sem pendências impeditivas. Revalidar a segunda entrega contra a main atualizada.

Estado inicial: threads e worktrees verificados; execução delegada. Aprovação deste plano não é aprovação das PRs.
