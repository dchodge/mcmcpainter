#!/bin/bash

# MCMC Painter GitHub Pages Deployment Script

echo "🎨 Deploying MCMC Painter to GitHub Pages..."

# Check if we're in the right directory
if [ ! -d "web_frontend" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Check if Emscripten is installed
if ! command -v emcc &> /dev/null; then
    echo "❌ Error: Emscripten not found. Please install it first:"
    echo "   git clone https://github.com/emscripten-core/emsdk.git"
    echo "   cd emsdk"
    echo "   ./emsdk install latest"
    echo "   ./emsdk activate latest"
    echo "   source ./emsdk_env.sh"
    exit 1
fi

# Build the WASM module
echo "🔨 Building WASM module..."
cd web_frontend
npm install
npm run build-wasm

if [ $? -ne 0 ]; then
    echo "❌ Error: WASM build failed"
    exit 1
fi

# Create docs directory
echo "📁 Creating docs directory..."
cd ..
mkdir -p docs

# Copy web files to docs
echo "📋 Copying files to docs..."
cp -r web_frontend/web/* docs/

# Check if files were copied
if [ ! -f "docs/index.html" ]; then
    echo "❌ Error: Files not copied correctly"
    exit 1
fi

echo "✅ Files copied successfully!"

# Show what was deployed
echo "📊 Deployment summary:"
echo "   - HTML files: $(find docs -name "*.html" | wc -l)"
echo "   - JS files: $(find docs -name "*.js" | wc -l)"
echo "   - WASM files: $(find docs -name "*.wasm" | wc -l)"
echo "   - PNG files: $(find docs -name "*.png" | wc -l)"

echo ""
echo "🚀 Ready to commit and push to GitHub!"
echo "   Run: git add docs/ && git commit -m 'Deploy to GitHub Pages' && git push origin main"
echo ""
echo "🌐 Your app will be available at: https://dchodge.github.io/mcmcpainter/"
