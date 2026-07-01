#!/bin/bash

# Parar o script se algum comando falhar
set -e

echo "🚀 Iniciando o script de compilação do Easy Notes..."

# 1. Verificar se o Xcode está instalado no caminho padrão
XCODE_PATH="/Applications/Xcode.app"
if [ ! -d "$XCODE_PATH" ]; then
    echo "⚠️  ERRO: O Xcode não foi encontrado em /Applications/Xcode.app."
    echo "Para compilar aplicativos SwiftUI/AppKit nativos no macOS, é necessário ter o Xcode completo instalado."
    exit 1
fi

# 2. Verificar se o xcode-select está apontando para o Xcode completo
CURRENT_SELECT=$(xcode-select -p)
TARGET_SELECT="/Applications/Xcode.app/Contents/Developer"

if [ "$CURRENT_SELECT" != "$TARGET_SELECT" ]; then
    echo "🔧 O xcode-select atual está apontando para: $CURRENT_SELECT"
    echo "Para compilar o aplicativo, precisamos apontar para o SDK completo do Xcode."
    echo "Por favor, insira a senha do seu Mac para autorizar a alteração temporária no terminal:"
    sudo xcode-select -s "$TARGET_SELECT"
    echo "✅ Caminho do xcode-select atualizado com sucesso!"
fi

# 3. Limpar compilações antigas
echo "🧹 Limpando diretórios de build anteriores..."
rm -rf ./build
rm -rf "./Easy Notes.app"

# 4. Compilar o app em modo Release via CLI
echo "📦 Compilando o Easy Notes em modo Release (isso pode levar alguns segundos)..."
xcodebuild -project "Easy Notes.xcodeproj" \
           -scheme "Easy Notes" \
           -configuration Release \
           -derivedDataPath "./build" \
           clean build

# 5. Extrair o arquivo executável .app para a raiz do projeto
BUILT_APP_PATH="./build/Build/Products/Release/Easy Notes.app"
if [ -d "$BUILT_APP_PATH" ]; then
    echo "🚚 Movendo o aplicativo compilado para a raiz do projeto..."
    cp -R "$BUILT_APP_PATH" ./
    echo "🎉 COMPILAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "👉 O arquivo 'Easy Notes.app' foi criado na raiz do seu projeto."
    echo "Você pode iniciá-lo dando duplo clique no Finder ou abrindo pelo terminal com: open \"Easy Notes.app\""
    
    # Oferecer para abrir o aplicativo
    echo -n "Deseja abrir o Easy Notes agora? (s/n): "
    read confirm
    if [[ "$confirm" =~ ^[sS]([iI][mM])?$ ]]; then
        open "Easy Notes.app"
    fi
else
    echo "❌ ERRO: O aplicativo compilado não foi encontrado em $BUILT_APP_PATH."
    exit 1
fi
