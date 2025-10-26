#!/bin/bash

echo "🎨 Starting MCMC Painter Web Server..."

# Check if module is built
if [ ! -f "web/mcmc_module.wasm" ]; then
    echo "⚠️  WASM module not found. Building first..."
    ./build.sh
    if [ $? -ne 0 ]; then
        echo "❌ Build failed. Cannot start server."
        exit 1
    fi
fi

# Start simple Python HTTP server
cd web
echo "🌐 Server starting at http://localhost:3000"
echo "📂 Serving from: $(pwd)"
echo ""
echo "Press Ctrl+C to stop"
echo ""

python3 -m http.server 3000


