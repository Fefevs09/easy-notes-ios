# Plano e Relatório Consolidado — Easy Notes (`feat-01` e `feat-02`)

Este documento consolida objetivos, estratégia de modelos, decisões arquiteturais, contratos entre módulos, resultados de revisão independente, evidências de build/testes no Xcode e pendências das entregas `feat-01` e `feat-02`, permitindo que qualquer thread futura retome ou audite o trabalho sem depender do histórico da conversa.

---

## 1. Base Git e Decisões

- **Base Git:** `origin/main` (`c481d0c`).
- **Decisões confirmadas pelo usuário (2026-11-24):**
  - `feat-01` parte diretamente da `main` atual (independente do PR #13).
  - `feat-02` segue a referência visual enviada: layout de 2 colunas com busca `/` na barra lateral esquerda, seções agrupadas com ícones, breadcrumb `Configurações / <Aba>`, cartões visuais de esquema de cores (**Sistema**, **Claro**, **Escuro**), grade de temas com duas esferas (claro/escuro) e sliders de interface com badges percentuais.

---

## 2. Estratégia de Modelos Executada (Tiering por Complexidade)

| Papel | Modelo / Provedor | Escopo Executado |
| :--- | :--- | :--- |
| Chief of Staff + Operator + Memory Manager + Doc Writer | Antigravity · Gemini 4 Neon (Medium) | Planejamento, contratos, ajustes pontuais de revisão (`feat-01`), integração combinada no Xcode e documentação |
| Engineer A (`feat-01`) | Antigravity · Gemini 3.8 Flash (Medium) | `PDFExportService`, `PDFExportOptions`, `NoteViewModel.exportPDF`, atalho `⇧⌘E` e `PDFExportTests` |
| Engineer B (`feat-02`) | Antigravity · Gemini 4 Neon (Medium) *(fallback aprovado após limite temporário de cota do Codex até 20:40)* | `AppSettingsStore`, `AppSettingsView`, `PixelTheme` dinâmico, `CoreDataStack.migrateStoreCopy`, entitlements/bookmarks e `AppSettingsTests` |
| Reviewer A (`feat-01`) | Antigravity · Gemini 3.8 Flash (High) | Revisão independente do PR #15 |
| Reviewer B (`feat-02`) | Antigravity · Gemini 4 Neon (High) + Re-check Gemini 3.8 Flash (Medium) | Revisão independente profunda (capturou 4 P1 + 6 P2) e re-check final após correções |

---

## 3. Matriz de Entregas, Revisões e Pull Requests

| Entrega | Branch / PR | Commit Final | Revisão Independente | Testes Xcode (`arm64`) |
| :--- | :--- | :--- | :--- | :--- |
| **`feat-01`** · Exportação PDF unificada | `t3/unify-pdf-export` → `main` · [PR #15](https://github.com/Fefevs09/easy-notes-ios/pull/15) | `c3cee1a` | **APROVADO** (0 P1, 0 P2, 0 P3 após ajuste de `onCompletion(URL?)` em erro e polish) | **67/67** (`0 failures`) |
| **`feat-02`** · Tela de Configuração | `t3/add-settings-screen-1` → `main` · [PR #14](https://github.com/fefevs09/easy-notes-ios/pull/14) | `0d69e11` | **APROVADO PARA REVISÃO HUMANA** (0 P1, 0 P2, 0 P3 após correção dos 4 P1 + 6 P2 e re-check) | **68/68** (`0 failures`) |
| **Integração combinada** (`feat-01` + `feat-02` sobre `origin/main`) | Validada em worktree temporário isolado | `c3cee1a` + `0d69e11` | **0 conflitos de merge** (`ContentView.swift` e `EditorToolbarView.swift` auto-mesclados) | **75/75** (`0 failures`, `BUILD SUCCEEDED`) |

---

## 4. Contratos Arquiteturais Consolidados

### `feat-01` — Exportação PDF
- **`PDFExportOptions`** (`Easy Notes/Services/PDFExportService.swift`): `includeGrid: Bool`, `pageRange: ClosedRange<Int>?`, `defaultDirectoryURL: URL?`, `parsePageRange(_:pageCount:)` e `validate(range:pageCount:)`.
- **`NoteViewModel.exportPDF(for:to:)`**: 100% retrocompatível, delegando para `exportPDF(for:to:options:)`; respeita `includeGrid` e `pageRange` preservando os índices originais de `shapes` e `strokes` com escrita atômica.
- **`PDFExportService`** (`@MainActor`): executa `flushTitleEdits()`, apresenta `NSSavePanel` via `beginSheetModal(for:)` com `PDFExportAccessoryView` acessível (grade + intervalo de páginas), retorna `nil` em `onCompletion` caso ocorra erro e preserva o ciclo de foco de `NotesView`.
- **Atalho:** `⇧⌘E` em `ContentView` quando há nota selecionada.

### `feat-02` — Tela de Configuração da Aplicação
- **`AppSettingsStore`** (`Easy Notes/Models/AppSettings.swift`): `UserDefaults` injetável (`easyNotes.settings.*`), `AppAppearanceMode` (`.system`/`.light`/`.dark`), `AppThemePreset` (*Editorial Paper*, *Sálvia*, *Terracota*, *Oceano*, *Âmbar*), `interfaceContrast`, `surfaceOpacity`, `penPresets` (5 presets editáveis com validação hex), padrões de caneta/borracha/papel/orientação, security-scoped bookmarks (`storageDirectoryBookmark`, `defaultExportDirectoryBookmark`) e `resetAll()` preservando o local de armazenamento customizado.
- **`ThemeAppearanceState` (`@Observable`) + `PixelTheme`**: reatividade em tempo real para cor de destaque, modo escuro (incluindo `notebookBannerTint`) e `surfaceOpacity`, mantendo a paleta editorial clara original intacta.
- **`CoreDataStack`** (`Easy Notes/Persistence/CoreDataStack.swift`): `migrateStoreCopy(to:)` via `NSPersistentStoreCoordinator.replacePersistentStore(...)` (checkpoint seguro de WAL + preservação de `_EXTERNAL_DATA` de `coverMediaData`), validação read-only, preservação intacta do banco original como backup, resolução de security-scoped bookmarks até `deinit` e fallback seguro com `storageLoadWarning`.
- **`AppSettingsView`** (`Easy Notes/Views/Settings/AppSettingsView.swift`): layout em 2 colunas com busca (`/` e `Escape`), breadcrumb `Configurações / <Aba>`, 7 abas (*Geral*, *Aparência*, *Canetas e Cores*, *Papel e Notas*, *Armazenamento*, *Exportação*, *Sobre*), acessível por `⌘,` (`Settings` scene) e botão de engrenagem no rodapé de `SidebarView`.

---

## 5. Pendências e Itens de Acompanhamento (Não Bloqueantes)

1. **Validação manual em janela macOS ao vivo (fora do escopo do `xctest` headless):**
   - Navegação completa com **VoiceOver** na janela de Configurações (`AppSettingsView`) e na `PDFExportAccessoryView` dentro do `NSSavePanel`.
   - Teste real de App Sandbox com escolha de pasta customizada no Finder, encerramento e reabertura do app confirmando persistência do security-scoped bookmark.
2. **Acoplamento opcional pós-merge (`feat-01` + `feat-02`):**
   - Conectar `AppSettingsStore.shared.includePaperGridInExport` e `defaultExportDirectory` como valores iniciais automáticos em `PDFExportService.shared.exportPDF` (mantidos desacoplados durante o desenvolvimento paralelo para zero conflito entre os PRs).
   - Conectar `AppSettingsStore.shared.confirmBeforeEmptyingTrash` ao botão "Esvaziar Lixeira" no cabeçalho de `NotesView.swift` (hoje aplicado no menu de contexto da `SidebarView`).

---

## 6. Status Final de Entrega

- **PR #15 (`feat-01`):** **MERGED** em `main` após aprovação humana em 2026-11-24.
- **PR #14 (`feat-02`):** **MERGED** em `main` após aprovação humana em 2026-11-24.
- **Branch `main`:** atualizada e sincronizada com `origin/main` contendo ambas as entregas e este registro consolidado.
