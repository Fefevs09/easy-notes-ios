# feat-02 · DMG para macOS

O script [`scripts/package-macos.sh`](../../../scripts/package-macos.sh) compila o esquema **Easy Notes** do projeto Xcode em **Release** para macOS. O DMG somente leitura contém `Easy Notes.app` e um link simbólico `Applications` para `/Applications`. A edição 1.0 (build 1) requer macOS 26.2 e contém código nativo para Apple silicon (`arm64`) e Intel (`x86_64`).

O script cria DerivedData temporário em cada execução. Ele verifica a imagem com `hdiutil verify`, monta em modo somente leitura e confere o link para Aplicativos, a identidade e a versão do bundle e o macOS mínimo no Info.plist e em cada arquitetura do Mach-O. Ele compara o executável montado com o executável preparado para empacotamento e verifica a assinatura estrita do app montado e o selo dos recursos. Depois de desmontar a imagem, gera e verifica seu SHA-256. O processo pode ser repetido a partir do mesmo commit e da mesma versão do Xcode. Cada imagem ganha seu próprio checksum, pois o sistema de arquivos da imagem e os carimbos de assinatura podem variar entre execuções.

## Pacote de teste local

A partir da raiz do checkout, informe um diretório novo dentro de um diretório existente.

```bash
work=$(mktemp -d /tmp/easy-notes-local.XXXXXX)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  ./scripts/package-macos.sh "$work/dist"
(cd "$work/dist" && shasum -a 256 -c ./*.sha256)
```

O nome termina em `-local.dmg`. O app recebe assinatura ad hoc com os entitlements do projeto. A máquina de validação reportou zero identidades válidas de assinatura. O DMG de teste tem assinatura de distribuição e notarização pendentes.

## Preparação da distribuição pública

1. Após integrar as entregas aprovadas, use um checkout limpo do commit escolhido na `main`. Registre o commit e a versão do Xcode usados para os artefatos.
2. No Mac de distribuição, disponibilize um certificado **Developer ID Application** e sua chave privada no chaveiro. Configure um perfil do `notarytool` no chaveiro. Passe somente os nomes da identidade e do perfil ao script.
3. Gere os artefatos com o Xcode selecionado para a distribuição.

   ```bash
   work=$(mktemp -d /tmp/easy-notes-release.XXXXXX)
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
   MACOS_SIGN_IDENTITY='Developer ID Application: NOME (TEAMID)' \
   MACOS_NOTARY_PROFILE='easy-notes-release' \
     ./scripts/package-macos.sh "$work/dist"
   (cd "$work/dist" && shasum -a 256 -c ./*.sha256)
   ```

   Esse modo assina o app com Hardened Runtime e carimbo de tempo seguro, assina o DMG, exige aceitação pelo serviço de notarização, anexa e valida o tíquete e verifica o DMG e o app montado com o Gatekeeper. Em caso de rejeição, use o ID informado pelo script para consultar o resultado com `xcrun notarytool log ID --keychain-profile easy-notes-release`. [Fluxo de empacotamento da Apple](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution?changes=_7)
4. Em um usuário ou uma VM de teste, baixe o candidato pelo canal de distribuição para que o macOS aplique a quarentena. Monte o DMG, copie o app para Aplicativos, ejete a imagem e abra a cópia instalada. Confira a instalação e a abertura em Apple silicon e Intel antes de publicar o DMG e o respectivo `.sha256` juntos.
5. Use o commit integrado como referência da release. Informe nas notas de versão o macOS mínimo, as arquiteturas e o estado confirmado de assinatura e notarização.

## Validação local

Xcode 27.2 (27B52), macOS 27.2.1 em Apple silicon. A suíte Debug com DerivedData temporário registrou 75 testes aprovados, sem falhas ou testes ignorados. Resultado em `/tmp/easy-notes-feat02-tests.L9Q9c6/Test.xcresult`.

```bash
work=$(mktemp -d /tmp/easy-notes-tests.XXXXXX)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project 'Easy Notes.xcodeproj' -scheme 'Easy Notes' \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$work/DerivedData" -resultBundlePath "$work/Test.xcresult" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO test
```

O build Release universal e a validação montada passaram. Em uma segunda montagem foi possível confirmar a assinatura ad hoc e os entitlements. Em uma cópia descartável do app, a alteração de um arquivo `.icns` fez o `codesign` rejeitar o recurso selado. O script recusou reutilizar o diretório de saída e aceitou somente o par completo de configurações para distribuição. A abertura manual do app empacotado e o fluxo Developer ID com notarização seguem para o ambiente de distribuição.

- DMG local em `/tmp/easy-notes-feat02.K7gweI/dist/Easy-Notes-1.0-1-macOS-universal-local.dmg`
- SHA-256 verificado `a477c95137d3cb807ac76f2672ea4e63a00ab045fe07ca4709934cd8a4682760`
