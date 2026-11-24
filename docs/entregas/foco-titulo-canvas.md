# FIX-04 — Foco após renomear a nota

Ao confirmar o título com Return, o editor grava as alterações pendentes e transfere o foco para a vista PDF da própria janela. Ao começar a desenhar com o mouse, a camada da página assume o foco e processa as coordenadas do mesmo clique. O título continua usando o binding e o salvamento diferido existentes. A camada de desenho fica fora do percurso de Tab.

## Reprodução e evidência

Na base `e8c9dd7`, o teste `testFirstPenDownAfterRenameEndsEditingAndBeginsStroke` editou um título em uma janela AppKit e entregou o primeiro evento de caneta à camada de desenho. O traço começou na posição esperada, mas a asserção de saída do editor de texto falhou. Com a correção, o mesmo teste passou e preservou o título acentuado.

O teste `testReturnInEditorCommitsTitleAndFocusesCanvas` monta a ContentView com Core Data em memória, substitui o título por “Última edição 📝” e envia Return à janela. Ele verifica o título gravado e o primeiro respondedor do PDF. Depois, retorna ao título e envia Tab, verificando que o próximo campo configurado na janela recebe a edição.

## Validação

Build do esquema Easy Notes concluído no macOS arm64. A suíte completa executou 55 testes, todos aprovados. Foram usados dados de teste em memória ou temporários e um diretório de build exclusivo.

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$(mktemp -d)" \
  -jobs 1 -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO build test
```

Os testes usam eventos sintetizados. A aparência do cursor de inserção, a composição com IME e o uso com mesa digitalizadora continuam sem verificação manual.
