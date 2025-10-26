#!/bin/bash

# Vercel Build Script for MCMC Painter

echo "🚀 Building MCMC Painter for Vercel..."

# Check if we're in the right directory
if [ ! -d "web_frontend" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
cd web_frontend
npm install

# Check if Emscripten is available
if ! command -v emcc &> /dev/null; then
    echo "⚠️  Warning: Emscripten not found. Installing via npm..."
    npm install -g emscripten
fi

# Build the WASM module
echo "🔨 Building WASM module..."
npm run build-wasm

if [ $? -ne 0 ]; then
    echo "❌ Error: WASM build failed"
    exit 1
fi

echo "✅ Build completed successfully!"
echo "📊 Build summary:"
echo "   - HTML files: $(find web -name "*.html" | wc -l)"
echo "   - JS files: $(find web -name "*.js" | wc -l)"
echo "   - WASM files: $(find web -name "*.wasm" | wc -l)"
echo "   - PNG files: $(find web -name "*.png" | wc -l)"
