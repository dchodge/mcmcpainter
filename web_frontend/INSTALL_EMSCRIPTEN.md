# Installing Emscripten

To compile the WASM module, you need to install Emscripten first.

## Quick Install (macOS/Linux)

```bash
# Download Emscripten SDK
cd ~
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# Install and activate the latest version
./emsdk install latest
./emsdk activate latest

# Activate PATH and environment variables in current terminal
source ./emsdk_env.sh
```

## Verify Installation

```bash
emcc --version
```

You should see something like:
```
emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 3.x.x
```

## Add to Your Shell Profile (Optional)

To make Emscripten available in all terminals, add this to your `~/.zshrc` or `~/.bashrc`:

```bash
# Emscripten
source ~/emsdk/emsdk_env.sh
```

## Compile the WASM Module

Once Emscripten is installed:

```bash
cd web_frontend
npm run build-wasm
```

This will create:
- `mcmc_wasm.js` - JavaScript glue code
- `mcmc_wasm.wasm` - WebAssembly binary

## Troubleshooting

### "emcc: command not found"
- Make sure you ran `source ./emsdk_env.sh`
- Or add Emscripten to your PATH permanently (see above)

### Compilation errors
- Check that `mcmc_wasm.cpp` is in the current directory
- Try the debug build: `npm run debug-wasm`
- Check Emscripten version: `emcc --version` (need 3.x or later)

### Browser can't load WASM
- Make sure both `mcmc_wasm.js` and `mcmc_wasm.wasm` are in the web_frontend directory
- Clear browser cache and refresh
- Check browser console for specific errors

## Alternative: Pre-compiled Version

If you don't want to install Emscripten, you could:
1. Ask someone else to compile it and share the files
2. Use GitHub Actions to auto-compile
3. Download a pre-built version (if available)

The compiled `.js` and `.wasm` files are portable and can be shared.


