# FIX-02 — Ícone do aplicativo

O catálogo `AppIcon` usa o caderno branco da marca da tela inicial. A referência é o `EasyNotesBrandMark(compact: true)` em `SidebarView.swift`, definido em `PixelTheme.swift` como o símbolo SF `book.pages.fill` com fonte de sistema semibold de 12 pt sobre uma base de 24 pt com cantos contínuos de raio 6 pt. O ícone contém apenas o símbolo e a base.

Os 10 PNGs de macOS reproduzem essa proporção com margem transparente. A cor é o violeta claro do preset Editorial em `AppSettings.swift` (`#6F52E0`). As três imagens opacas de 1024 px de iOS mantêm a proporção do glifo e preenchem o quadrado para a máscara do sistema. A versão escura usa o violeta escuro do mesmo preset (`#9E88F5`) e a tingível usa branco sobre preto.

## Verificação

- Os 13 PNGs correspondem aos nomes, dimensões e escalas registrados no `Contents.json`. Os arquivos de macOS são RGBA e os de iOS são RGB.
- No app compilado de macOS, `CFBundleIconFile` aponta para `AppIcon`. O bundle inclui `AppIcon.icns`, e `assetutil` registra as dez representações de 16 a 1024 px no `Assets.car`.
- A inspeção visual a 16 e 32 px cobriu os PNGs do catálogo e as representações de 16 pt extraídas do `AppIcon.icns` com `iconutil`. O caderno branco manteve contraste e contorno reconhecível nos dois tamanhos.
- O `actool` compilou separadamente o catálogo para iPhone e iPad com o destino mínimo 26.5.

### Build e testes no macOS

Xcode 27.2 (27B52) com DerivedData isolado.

```sh
FIX_DIR=$(mktemp -d /tmp/easy-notes-fix02.XXXXXX)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "Easy Notes.xcodeproj" -scheme "Easy Notes" \
  -destination "platform=macOS" -derivedDataPath "$FIX_DIR/DerivedData" \
  -resultBundlePath "$FIX_DIR/tests.xcresult" -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO build test
```

O Xcode concluiu o build e executou 75 testes com sucesso, sem falhas ou testes ignorados. A verificação de iOS cobriu a compilação dos recursos e confirmou as versões padrão, escura e tingível no `Assets.car`.
