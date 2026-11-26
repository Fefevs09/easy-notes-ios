<p align="center">
  <img src="Easy%20Notes/Assets.xcassets/AppIcon.appiconset/icon_128x128%402x.png" width="128" height="128" alt="Ícone do Easy Notes">
</p>

<h1 align="center">Easy Notes</h1>

<p align="center">Seu caderno digital no Mac. Reúna anotações, desenhos à mão livre e PDFs em um app nativo, totalmente gratuito e com código-fonte público.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26.2%2B-222222?logo=apple" alt="macOS 26.2 ou posterior">
  <img src="https://img.shields.io/badge/app-gratuito-26734d" alt="Totalmente gratuito">
  <a href="https://github.com/Fefevs09/easy-notes-ios/releases/tag/v1.0-build.1-preview.1"><img src="https://img.shields.io/badge/vers%C3%A3o-1.0%20pr%C3%A9via-6747c7" alt="Versão 1.0 em prévia"></a>
</p>

## Por dentro do Easy Notes

### Do rascunho à página de estudo

![Editor do Easy Notes com miniatura da página, ferramentas de desenho e um resumo ilustrado do sistema solar](docs/imagens/nota-sistema-solar.png)

*Nota de exemplo sobre o sistema solar. A imagem combina a interface do editor com um PDF de demonstração.*

### Uma biblioteca para estudos, rotina e projetos

![Biblioteca em grade com três notas de exemplo organizadas em cadernos](docs/imagens/biblioteca.png)

*Resumos de aula, ideias para a casa e planos para a semana em cadernos separados.*

## Download para macOS

**[Baixar Easy Notes 1.0 (.dmg)](https://github.com/Fefevs09/easy-notes-ios/releases/download/v1.0-build.1-preview.1/Easy-Notes-1.0-1-macOS-universal-local.dmg)**

A prévia (build 1) requer **macOS 26.2 ou posterior**. O pacote é universal para Apple Silicon e Intel. A abertura em Mac Intel ainda está pendente de validação. A assinatura é ad hoc e o Gatekeeper pode bloquear a abertura enquanto a prévia estiver sem notarização. [Notas da versão e checksum SHA-256](https://github.com/Fefevs09/easy-notes-ios/releases/tag/v1.0-build.1-preview.1)

## Sobre o projeto

O Easy Notes é um caderno digital para estudar, planejar e revisar documentos no Mac. Você pode começar com uma página em branco ou importar um PDF e guardar o resultado no mesmo caderno das suas outras notas.

## O que você pode fazer

- **Organize e encontre suas notas.** Agrupe páginas em cadernos, personalize as capas e encontre uma nota pelo título. Alterne entre grade e lista conforme a quantidade de notas.
- **Escreva, desenhe e destaque.** Use canetas, lápis e marca-texto para esboçar ideias. Adicione formas a diagramas e escolha entre papel liso, pautado, quadriculado ou pontilhado.
- **Estude e revise PDFs.** Importe um documento, navegue pelas miniaturas, aproxime a página com o zoom e anote diretamente sobre ela. Exporte em PDF para compartilhar.
## Por que usar o Easy Notes?

- **Seu material fica no Mac.** A biblioteca é salva localmente e funciona sem cadastro ou assinatura.
- **As ferramentas acompanham o trabalho.** Você pode desenhar um esquema em uma página quadriculada, destacar trechos de um PDF e voltar a qualquer nota pela biblioteca.
- **Compartilhe fora do app.** Exporte em PDF para enviar suas anotações a quem usa outro aplicativo.

## Comparação com alternativas

| Aplicativo | Quando faz sentido |
| --- | --- |
| **Easy Notes** | Para reunir cadernos locais, páginas de desenho com tipos de papel e PDFs anotados em uma biblioteca. |
| **Notas da Apple** | Para trabalhar com notas e usar as ferramentas de marcação em PDFs e imagens anexados. [Guia da Apple](https://support.apple.com/en-mn/guide/notes/apdef7f74190/mac) |
| **Pré-Visualização** | Para abrir um PDF ou uma imagem diretamente e adicionar destaques, notas e formas ao arquivo. [Guia da Apple](https://support.apple.com/guide/mac-help/preview-a-file-mchlgtd_prev01/mac) |

## Início rápido

1. Baixe o DMG na seção [Download para macOS](#download-para-macos).
2. Abra a imagem, arraste o **Easy Notes** para **Aplicativos** e abra o app.
3. Na primeira abertura, clique em **Começar**. Na biblioteca, escolha **Nova nota** para escrever e desenhar ou **Importar PDF** para anotar um documento.

## Tecnologias utilizadas

| Tecnologia | Uso no projeto |
| --- | --- |
| Swift e SwiftUI | Aplicativo nativo e interface da biblioteca, do editor e dos ajustes. |
| AppKit e PDFKit | Interação com o canvas no macOS, exibição de PDFs e camadas de anotação. |
| Core Data e SQLite | Persistência local de notas, cadernos, traços e formas. |
| XCTest | Testes de comportamento da biblioteca, do editor e da exportação. |

## Arquitetura

O projeto usa MVVM. As views apresentam a biblioteca e o editor. `NoteViewModel` coordena notas e cadernos, e `CanvasViewModel` mantém o estado das ferramentas de desenho. `CoreDataStack` abre o banco local, e `PDFExportService` coordena a exportação. [Histórico das entregas](docs/entregas/README.md)

## Roadmap

- [x] Disponibilizar a prévia universal em DMG.
- [x] Incluir boas-vindas na primeira abertura e atualizar o ícone do app e os controles de caneta.
- [ ] Assinar com Developer ID e notarizar o pacote de distribuição.
- [ ] Validar a abertura do pacote baixado em Apple Silicon e Intel e concluir as verificações com teclado e VoiceOver.

[Registro de distribuição e pendências](docs/entregas/ui-distribuicao/README.md)

## Como contribuir

Para sugerir uma melhoria ou relatar um problema, descreva o resultado esperado, o que aconteceu e a versão do macOS. [Issues no GitHub](https://github.com/Fefevs09/easy-notes-ios/issues)

Para trabalhar no código, abra `Easy Notes.xcodeproj` no Xcode, selecione o esquema **Easy Notes** e o destino **My Mac**. Use **⌘R** para executar e **⌘U** para rodar os testes. O projeto foi validado com o Xcode 27.2. Envie seu pull request com um resumo da mudança e os testes que executou. [Pull requests no GitHub](https://github.com/Fefevs09/easy-notes-ios/pulls)

## Contribuidores

Felipe Vieira mantém o projeto. [Histórico de contribuidores](https://github.com/Fefevs09/easy-notes-ios/graphs/contributors)

## Licença

O aplicativo é gratuito para uso e o código-fonte está disponível para consulta neste repositório. O projeto ainda não declara uma licença de código aberto.
