#!/bin/bash

echo "🎨 Building MCMC Painter WebAssembly Module..."

# Check if emscripten is available
if ! command -v emcc &> /dev/null; then
    echo "📦 Setting up Emscripten..."
    
    # Check if emsdk directory exists
    if [ ! -d "emsdk" ]; then
        echo "⬇️  Downloading Emscripten SDK..."
        git clone https://github.com/emscripten-core/emsdk.git
    fi
    
    cd emsdk
    echo "🔧 Installing latest Emscripten..."
    ./emsdk install latest
    ./emsdk activate latest
    source ./emsdk_env.sh
    cd ..
fi

echo "🚀 Compiling C++ MCMC Painter to WebAssembly..."

# Create web output directory if it doesn't exist
mkdir -p web

# Compile with optimizations and embind
emcc src/mcmc_painter.cpp -o web/mcmc_module.js \
  -s WASM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s MODULARIZE=1 \
  -s EXPORT_NAME="'MCMCModule'" \
  -s EXPORTED_RUNTIME_METHODS="['ccall', 'cwrap']" \
  -s EXPORTED_FUNCTIONS="['_malloc', '_free']" \
  -O3 \
  -std=c++11 \
  --bind

if [ $? -eq 0 ]; then
    echo "✅ MCMC Painter WebAssembly module built successfully!"
    echo "📁 Output: web/mcmc_module.js + web/mcmc_module.wasm"
    ls -lh web/mcmc_module.*
else
    echo "❌ Build failed!"
    exit 1
fi


