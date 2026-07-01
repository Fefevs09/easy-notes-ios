# Gemini Agent Guidelines & Technical Specifications 🤖

Este arquivo serve como guia de arquitetura e referência técnica para agentes de IA que realizem manutenção, extensão ou refatorações neste projeto. Ele detalha as decisões estruturais críticas, esquemas de dados e regras de renderização.

---

## 🏛️ Diretrizes de Arquitetura (MVVM + Persistence)

O projeto segue um padrão rigoroso de separação de responsabilidades (MVVM) com fluxo de dados reativo unidirecional nas views secundárias e acoplamento em bindings locais para digitação livre de lag.

```mermaid
graph TD
    CD[Core Data Stack] <--> VM[NoteViewModel]
    CD <--> CVM[CanvasViewModel]
    VM -->|@Published SelectedNote| CV[ContentView]
    CVM -->|Drawing State / Tool Options| CV
    CV -->|Modular Injections| SB[SidebarView]
    CV -->|Modular Injections| NL[NoteListView]
    CV -->|ZStack Overlap| TE[TextEditorView]
    CV -->|ZStack Overlap| DC[DrawingCanvasView]
```

---

## 💾 Persistência Core Data Programática

Para evitar arquivos XML proprietários do Xcode (`.xcdatamodeld`) que causam conflitos de merge recorrentes em ferramentas de controle de versão, o banco de dados é inicializado diretamente no código Swift (`Persistence/CoreDataStack.swift`).

### Esquema de Entidades e Atributos:

1. **Notebook** (`Notebook`):
   - `id`: `UUID` (Não opcional)
   - `name`: `String` (Não opcional)
   - *Relacionamento:* `notes` (Um-para-Muitos para `Note`, regra de deleção: **Cascade**).

2. **Note** (`Note`):
   - `id`: `UUID` (Não opcional)
   - `title`: `String` (Não opcional)
   - `content`: `String` (Não opcional)
   - `createdAt`: `Date` (Não opcional)
   - `updatedAt`: `Date` (Não opcional)
   - *Relacionamentos:* 
     - `notebook`: `Notebook?` (Muitos-para-Um, regra de deleção: **Nullify**).
     - `strokes`: `NSSet?` (Um-para-Muitos para `Stroke`, regra de deleção: **Cascade**).

3. **Stroke** (`Stroke`):
   - `id`: `UUID` (Não opcional)
   - `points`: `String` (Não opcional) — Formato de serialização personalizada: `"x1,y1;x2,y2;x3,y3..."`
   - `color`: `String` (Hexadecimal do traço: `"#007AFF"`)
   - `width`: `Float` (Espessura do pincel)
   - *Relacionamento:* `note`: `Note?` (Muitos-para-Um, regra de deleção: **Nullify**).

---

## 🎨 Sistema de Desenho Livre (Drawing Canvas)

A tela de desenho livre (`DrawingCanvasView`) é construída sobre uma subclasse nativa de `NSView` (`NSDrawingCanvas`) e encapsulada em `NSViewRepresentable` do SwiftUI.

### 📐 Sistema de Coordenadas & Conversões
O AppKit utiliza a origem `(0,0)` no **canto inferior esquerdo** da view, enquanto o SwiftUI/CoreGraphics convencionalmente utiliza a origem no **canto superior esquerdo**. 
- Ao capturar eventos de mouse na view AppKit, os pontos coletados pelo método `convert(event.locationInWindow, from: nil)` são mapeados diretamente para as coordenadas locais do `NSView`.
- **Serialização de Pontos:** Os traços são mapeados em um array de `CGPoint` locais e serializados em uma única `String` separada por pontos e vírgulas (ex: `"102.5,450.0;105.0,452.5;110.0,460.0"`). Isso confere performance excelente de escrita e leitura de I/O em disco.

### 🖌️ Renderização de Bezier Paths
- Para garantir curvas perfeitamente suavizadas e contínuas (sem serrilhados), os pontos serializados são lidos e reconstruídos em instâncias de `NSBezierPath`.
- Propriedades obrigatórias para pincel de alta fidelidade:
  - `path.lineWidth = strokeWidth`
  - `path.lineCapStyle = .round`
  - `path.lineJoinStyle = .round`

---

## ⚡ Otimização de UI e Evitação de Lag

1. **Evitação de Lag no Editor de Texto (`TextEditorView`):**
   Atualizar o Core Data diretamente a cada caractere pressionado no `NSTextView` gerará travamentos frequentes na UI. 
   - **Solução:** `ContentView` possui estados de entrada locais `@State private var activeTitle` e `@State private var activeContent`. 
   - A sincronização com a thread principal e banco de dados ocorre de forma assíncrona por meio do modificador `.onChange(of: activeContent)` e `.onChange(of: activeTitle)`, permitindo que o AppKit processe a digitação com latência zero e execute a gravação no Core Data em background de forma transparente.

2. **Reconstrução Segura do Wrapper (`.id` modifier):**
   Ao alternar notas na lista central, use o modificador `.id(loadingNoteId)` no wrapper representável. Isso garante que o coordenador do `NSTextView` seja recriado de forma limpa, limpando históricos de desfazer/refazer (UndoManager) e seleções residuais da nota anterior.

3. **Oclusão e ZStack:**
   O modo de escrita e o modo de desenho livre são sobrepostos em um `ZStack` localizado na coluna de detalhes. Quando `canvasVM.isDrawingMode` é ativado, o `DrawingCanvasView` é colocado no topo do `TextEditorView` para capturar os cliques e gestos de desenho livre, enquanto o editor de texto reduz sua opacidade para `0.45` para servir como guia de fundo translúcido (efeito glassmorphism moderno).
