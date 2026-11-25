#!/bin/bash
set -euo pipefail

fail() { printf 'Erro: %s\n' "$*" >&2; exit 1; }

[[ $# == 1 && -n "$1" ]] || fail "Uso: $0 DIRETORIO_NOVO_DE_SAIDA"
output=$1
[[ ! -e "$output" && ! -L "$output" ]] || fail "O diretório de saída já existe."
root=$(cd "$(dirname "$0")/.." && pwd)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
identity=${MACOS_SIGN_IDENTITY:-}
notary_profile=${MACOS_NOTARY_PROFILE:-}
sign_args=(--sign - --timestamp=none)
suffix=-local
if [[ -n "$identity" || -n "$notary_profile" ]]; then
    [[ "$identity" == "Developer ID Application: "* && -n "$notary_profile" ]] ||
        fail "Informe MACOS_SIGN_IDENTITY (Developer ID Application) e MACOS_NOTARY_PROFILE juntos."
    sign_args=(--sign "$identity" --timestamp)
    suffix=
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/easy-notes-dmg.XXXXXX")
mount="$work/mount"
mounted=0
pending=
cleanup() {
    if [[ -n "$pending" ]]; then rm -rf "$pending"; fi
    if [[ "$mounted" == 1 ]] && ! hdiutil detach "$mount" >&2; then
        printf 'Desmonte a imagem em %s antes de remover %s.\n' "$mount" "$work" >&2
        return 1
    fi
    rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcode=(xcodebuild -project "$root/Easy Notes.xcodeproj" -scheme 'Easy Notes'
       -configuration Release -destination 'generic/platform=macOS'
       -derivedDataPath "$work/DerivedData" 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO
       CODE_SIGNING_ALLOWED=NO)

"${xcode[@]}" -showBuildSettings -json > "$work/settings.json"
setting() { plutil -extract "0.buildSettings.$1" raw -o - "$work/settings.json"; }
[[ "$(setting TARGET_NAME)" == "Easy Notes" ]] || fail "Configuração do alvo Easy Notes ausente."
version=$(setting MARKETING_VERSION)
build=$(setting CURRENT_PROJECT_VERSION)
minimum=$(setting MACOSX_DEPLOYMENT_TARGET)
bundle_id=$(setting PRODUCT_BUNDLE_IDENTIFIER)
product=$(setting FULL_PRODUCT_NAME)
[[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ && "$build" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
    fail "Versão ou número de build inválido."
[[ "$product" == 'Easy Notes.app' ]] || fail "Produto inesperado: $product"

"${xcode[@]}" build >&2
mkdir "$work/staging" "$mount"
staged_app="$work/staging/$product"
ditto "$(setting TARGET_BUILD_DIR)/$product" "$staged_app"
codesign "${sign_args[@]}" --options runtime --generate-entitlement-der \
    --entitlements "$root/Easy Notes/Easy Notes.entitlements" "$staged_app"
ln -s /Applications "$work/staging/Applications"

name="Easy-Notes-${version}-${build}-macOS-universal${suffix}.dmg"
image="$work/$name"
hdiutil create -srcfolder "$work/staging" -volname 'Easy Notes' -format UDZO "$image"

if [[ -n "$identity" ]]; then
    codesign "${sign_args[@]}" --identifier "$bundle_id.dmg" "$image"
    submit_result=0
    xcrun notarytool submit "$image" --keychain-profile "$notary_profile" \
        --output-format json > "$work/notary.json" || submit_result=$?
    submission=$(plutil -extract id raw -o - "$work/notary.json" 2>/dev/null) ||
        fail "Serviço de notarização não retornou um ID de envio."
    printf 'ID de envio à notarização: %s\n' "$submission" >&2
    [[ "$submit_result" == 0 ]] || fail "Falha no envio à notarização ($submission)."
    xcrun notarytool wait "$submission" --keychain-profile "$notary_profile" \
        --output-format json > "$work/wait.json" || fail "Falha ao aguardar envio $submission."
    status=$(plutil -extract status raw -o - "$work/wait.json")
    [[ "$status" == Accepted ]] || fail "Notarização: $status (envio $submission)."
    xcrun stapler staple "$image"
    xcrun stapler validate "$image"
    codesign --verify --strict "$image"
    spctl --assess --type open --context context:primary-signature "$image"
    printf 'Notarização aceita (envio %s).\n' "$submission"
else
    printf 'DMG de teste local. App com assinatura ad hoc.\n'
fi

hdiutil verify "$image"
hdiutil attach -readonly -nobrowse -mountpoint "$mount" "$image"
mounted=1
app="$mount/$product"
plist="$app/Contents/Info.plist"
[[ -d "$app" && ! -L "$app" && -L "$mount/Applications" &&
   "$(readlink "$mount/Applications")" == /Applications ]] ||
    fail "App ou atalho Applications ausente ou incorreto."

check_plist() {
    [[ "$(plutil -extract "$1" raw -o - "$plist")" == "$2" ]] ||
        fail "Valor inesperado para $1 no app montado."
}
check_plist CFBundleIdentifier "$bundle_id"
check_plist CFBundleShortVersionString "$version"
check_plist CFBundleVersion "$build"
check_plist LSMinimumSystemVersion "$minimum"
executable=$(plutil -extract CFBundleExecutable raw -o - "$plist")
[[ "$executable" == "$(setting EXECUTABLE_NAME)" ]] || fail "Nome de executável inesperado."
binary="$app/Contents/MacOS/$executable"
[[ -f "$binary" && -x "$binary" && ! -L "$binary" ]] || fail "Executável inválido."
cmp "$binary" "$staged_app/Contents/MacOS/$executable"
architectures=$(lipo -archs "$binary")
[[ "$architectures" == 'x86_64 arm64' || "$architectures" == 'arm64 x86_64' ]] ||
    fail "Arquiteturas inesperadas: $architectures"
for arch in arm64 x86_64; do
    build_version=$(xcrun vtool -arch "$arch" -show-build "$binary")
    platform=$(awk '$1 == "platform" {print $2}' <<< "$build_version")
    minos=$(awk '$1 == "minos" {print $2}' <<< "$build_version")
    [[ "$platform" == MACOS && "$minos" == "$minimum" ]] ||
        fail "Plataforma ou macOS mínimo inesperado para $arch: $platform $minos"
done
codesign --verify --deep --strict --all-architectures --verbose=2 "$app"
if [[ -n "$identity" ]]; then
    spctl --assess --type execute "$app"
fi
printf 'App montado validado: %s %s (%s), macOS %s+, %s.\n' \
    "$bundle_id" "$version" "$build" "$minimum" "$architectures"
hdiutil detach "$mount"
mounted=0

(cd "$work" && shasum -a 256 "$name" > "$name.sha256")
pending=$(mktemp -d "$(dirname "$output")/.easy-notes-release.XXXXXX")
mv "$image" "$work/$name.sha256" "$pending/"
(cd "$pending" && shasum -a 256 -c "$name.sha256")
# Darwin's exclusive rename publishes both files atomically, even with concurrent callers.
xcrun swift -e '
import Darwin
guard renamex_np(CommandLine.arguments[1], CommandLine.arguments[2], UInt32(RENAME_EXCL)) == 0 else {
    perror("renamex_np")
    exit(1)
}' "$pending" "$output"
pending=
printf '%s\n' "$output/$name" "$output/$name.sha256"
