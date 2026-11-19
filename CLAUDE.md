# Contexto Inicial do Projeto (Alethe AI Briefing)

> Este repositório foi clonado via Alethe. O briefing abaixo descreve a aplicação para orientar sua assistência.

## Tecnologias Detectadas
- Não especificada

## Resumo do Repositório (README)
```markdown
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
│...
```

## Instrução Importante para o Agente
Ao iniciar a conversa com o usuário neste repositório, faça um resumo executivo direto de 2 a 3 frases explicando o propósito deste projeto.
