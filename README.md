# Easy Notes 📝

Um aplicativo macOS premium de anotações com suporte a organização em cadernos (notebooks) e desenho livre (hand-drawn canvas sketching) integrado.

Desenvolvido nativamente em **SwiftUI** e **AppKit** para macOS 13+, seguindo rigorosamente o padrão arquitetural **MVVM** e persistência local via **Core Data** programático.

---

## 📂 Estrutura do Projeto

O código-fonte segue a estrutura organizada por domínios e camadas de responsabilidade:

```text
Easy Notes/
├── Models/
│   ├── Note.swift           # Entidade de Notas (Persistida)
│   ├── Notebook.swift       # Entidade de Cadernos de Notas (Persistida)
│   └── Stroke.swift         # Entidade de Traços de Desenho Livre (Persistida)
├── Views/
│   ├── ContentView.swift    # Tela principal integradora de colunas
│   ├── Sidebar/
│   │   └── SidebarView.swift# Coluna 1: Lista e ações de Cadernos
│   ├── NoteList/
│   │   └── NoteListView.swift# Coluna 2: Busca e lista de Notas filtradas
│   ├── Editor/
│   │   ├── TextEditorView.swift # Wraps NSTextView (Edição Rich Text/Focada)
│   │   └── DrawingCanvasView.swift # Subclasse de NSView (Interface de Desenho)
│   └── Toolbar/
│       └── EditorToolbarView.swift # Barra superior com estatísticas e ferramentas de desenho
├── ViewModels/
│   ├── NoteViewModel.swift  # ViewModel MVVM das Notas e Cadernos
│   └── CanvasViewModel.swift# ViewModel MVVM do Canvas de Desenho Livre
├── Persistence/
│   └── CoreDataStack.swift  # Inicializador programmatico do Core Data Stack
└── Resources/
    └── Assets.xcassets      # Catálogo de assets e cores do aplicativo
```

---

## 🛠️ Tecnologias e Recursos Utilizados

- **Core Data (Programático):** Definição de esquema de banco de dados diretamente em código Swift (`NSManagedObjectModel`). Garante que a compilação seja limpa e elimina conflitos de mesclagem (merge conflicts) em arquivos XML `.xcdatamodeld`.
- **AppKit/NSTextView:** Encapsulado via `NSViewRepresentable` para prover controle total das margens e espaçamento de linhas (Line-Height), resultando em um editor com tipografia e legibilidade de nível premium.
- **Desenho Livre Integrado:** Subclasse nativa de `NSView` capturando eventos de mouse (`mouseDown`, `mouseDragged`, `mouseUp`) para renderizar curvas bezier dinâmicas, persistindo pontos, cor e espessura diretamente nas entidades Core Data associadas.
- **Navegação de 3 Colunas:** Implementado utilizando o moderno `NavigationSplitView` com efeitos de desfoque translúcido (`.ultraThinMaterial`) nativos do macOS Ventura+.

---

## 🚀 Como Compilar e Executar

1. Certifique-se de que o **Xcode 14.0+** esteja instalado em seu Mac rodando macOS 13+.
2. Abra o arquivo `Easy Notes.xcodeproj` no Xcode.
3. Selecione o target `Easy Notes` e a plataforma `My Mac`.
4. Pressione `Cmd + R` para rodar ou compile via terminal:
   ```bash
   xcodebuild -project "Easy Notes.xcodeproj" -scheme "Easy Notes" -configuration Debug build
   ```

---

## 💡 Diretrizes de Desenvolvimento

Ao adicionar novas features ou realizar manutenções, siga estas premissas:
1. **Preservação de MVVM:** Mantenha a separação de conceitos entre views e a manipulação de objetos gerenciados (Core Data). Use os ViewModels `NoteViewModel` e `CanvasViewModel`.
2. **Design System Premium:** Utilize fontes arredondadas, opacidades graduadas, espaçamentos generosos de no mínimo 16-24pt e animações de transição suaves.
3. **Persistência Programática:** Se precisar estender o banco de dados, faça-o modificando o `CoreDataStack.swift` diretamente em código Swift.
