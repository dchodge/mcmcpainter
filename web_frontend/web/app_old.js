class MCMCPainterApp {
    constructor() {
        this.isRunning = false;
        this.currentImage = null;
        this.originalCanvas = null;
        this.paintedCanvas = null;
        this.originalCtx = null;
        this.paintedCtx = null;
        this.wasmModule = null;
        this.mcmcPainter = null;
        this.imageData = null;
        this.imageWidth = 0;
        this.imageHeight = 0;
        
        this.initializeElements();
        this.setupEventListeners();
        this.loadWebAssembly();
    }
    
    initializeElements() {
        this.uploadSection = document.getElementById('uploadSection');
        this.imageInput = document.getElementById('imageInput');
        this.imagePreview = document.getElementById('imagePreview');
        this.startBtn = document.getElementById('startBtn');
        this.progressSection = document.getElementById('progressSection');
        this.progressFill = document.getElementById('progressFill');
        this.progressText = document.getElementById('progressText');
        this.canvasContainer = document.getElementById('canvasContainer');
        this.statsSection = document.getElementById('statsSection');
        this.errorMessage = document.getElementById('errorMessage');
        this.successMessage = document.getElementById('successMessage');
        
        this.originalCanvas = document.getElementById('original-canvas');
        this.paintedCanvas = document.getElementById('painted-canvas');
        this.originalCtx = this.originalCanvas.getContext('2d');
        this.paintedCtx = this.paintedCanvas.getContext('2d');
    }
    
    setupEventListeners() {
        // File input
        this.imageInput.addEventListener('change', (e) => this.handleFileSelect(e));
        
        // Drag and drop
        this.uploadSection.addEventListener('dragover', (e) => this.handleDragOver(e));
        this.uploadSection.addEventListener('dragleave', (e) => this.handleDragLeave(e));
        this.uploadSection.addEventListener('drop', (e) => this.handleDrop(e));
        
        // Default image buttons
        document.getElementById('useLotusBtn').addEventListener('click', () => this.useDefaultImage('lotus'));
        document.getElementById('useViLeighBtn').addEventListener('click', () => this.useDefaultImage('vi_leigh'));
        document.getElementById('useOctopusBtn').addEventListener('click', () => this.useDefaultImage('octopus'));
        
        // Start button
        this.startBtn.addEventListener('click', () => this.startPainting());
    }
    
    handleDragOver(e) {
        e.preventDefault();
        this.uploadSection.classList.add('dragover');
    }
    
    handleDragLeave(e) {
        e.preventDefault();
        this.uploadSection.classList.remove('dragover');
    }
    
    handleDrop(e) {
        e.preventDefault();
        this.uploadSection.classList.remove('dragover');
        
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            this.processFile(files[0]);
        }
    }
    
    handleFileSelect(e) {
        const file = e.target.files[0];
        if (file) {
            this.processFile(file);
        }
    }
    
    async processFile(file) {
        if (!file.type.startsWith('image/')) {
            this.showError('Please select a valid image file.');
            return;
        }
        
        try {
            const img = new Image();
            img.onload = () => {
                this.currentImage = img;
                this.imagePreview.src = URL.createObjectURL(file);
                this.imagePreview.style.display = 'block';
                
                // Process image
                this.processImage(img);
                
                this.startBtn.disabled = false;
                this.hideMessages();
                this.showSuccess(`Image loaded! ${img.width}×${img.height}px. Ready to paint.`);
            };
            img.src = URL.createObjectURL(file);
            
        } catch (error) {
            console.error('Error processing image:', error);
            this.showError('Failed to process image. Please try again.');
        }
    }
    
    async useDefaultImage(imageName = 'lotus') {
        try {
            // Map of image names to display names
            const imageNames = {
                'lotus': 'Lotus',
                'vi_leigh': 'Vivien Leigh',
                'octopus': 'Octopus'
            };
            
            // Load the selected default image
            const response = await fetch(`public/${imageName}.png`);
            if (!response.ok) {
                throw new Error(`Failed to load ${imageNames[imageName]} image`);
            }
            
            const blob = await response.blob();
            const file = new File([blob], `${imageName}.png`, { type: 'image/png' });
            
            // Process the default image
            await this.processFile(file);
            
        } catch (error) {
            console.error('Error loading default image:', error);
            this.showError('Failed to load default image. Please upload your own image.');
        }
    }
    
    processImage(img) {
        // Get max dimension parameter
        const maxDim = parseInt(document.getElementById('maxDimension').value) || 400;
        
        // Scale image to max dimension
        const scale = Math.min(maxDim / Math.max(img.width, img.height), 1);
        this.imageWidth = Math.round(img.width * scale);
        this.imageHeight = Math.round(img.height * scale);
        
        // Create temporary canvas for processing
        const tempCanvas = document.createElement('canvas');
        tempCanvas.width = this.imageWidth;
        tempCanvas.height = this.imageHeight;
        const tempCtx = tempCanvas.getContext('2d');
        tempCtx.drawImage(img, 0, 0, this.imageWidth, this.imageHeight);
        
        // Get image data
        const imgData = tempCtx.getImageData(0, 0, this.imageWidth, this.imageHeight);
        
        // Convert to flat array [H*W*3] for WebAssembly
        this.imageData = [];
        for (let y = 0; y < this.imageHeight; y++) {
            for (let x = 0; x < this.imageWidth; x++) {
                const idx = (y * this.imageWidth + x) * 4;
                this.imageData.push(
                    imgData.data[idx] / 255,     // R
                    imgData.data[idx + 1] / 255, // G
                    imgData.data[idx + 2] / 255  // B
                );
            }
        }
        
        // Setup display canvases
        this.setupCanvases(img);
        
        console.log(`Image processed: ${this.imageWidth}×${this.imageHeight}px`);
    }
    
    setupCanvases(img) {
        const maxDisplay = 500; // Maximum display size
        const scale = Math.min(maxDisplay / this.imageWidth, maxDisplay / this.imageHeight);
        const displayWidth = Math.round(this.imageWidth * scale);
        const displayHeight = Math.round(this.imageHeight * scale);
        
        // Set canvas dimensions
        this.originalCanvas.width = displayWidth;
        this.originalCanvas.height = displayHeight;
        this.paintedCanvas.width = displayWidth;
        this.paintedCanvas.height = displayHeight;
        
        // Draw original image
        this.originalCtx.drawImage(img, 0, 0, displayWidth, displayHeight);
        
        // Initialize painted canvas with white background
        this.paintedCtx.fillStyle = 'white';
        this.paintedCtx.fillRect(0, 0, displayWidth, displayHeight);
    }
    
    startPainting() {
        if (!this.currentImage || this.isRunning || !this.wasmModule) return;
        
        const seed = 42; // Fixed seed for reproducibility
        const maxIterations = parseInt(document.getElementById('maxIterations').value) || 100000;
        const updateFrequency = parseInt(document.getElementById('updateFrequency').value) || 100;
        const betaInit = parseFloat(document.getElementById('betaInit').value) || 0.1;
        const betaFinal = parseFloat(document.getElementById('betaFinal').value) || 2.0;
        let kLambda = parseFloat(document.getElementById('kLambda').value) || 0;
        
        // Auto-set K_lambda if 0
        if (kLambda === 0) {
            kLambda = 0.5 * this.imageWidth;
        }
        
        console.log('Starting MCMC with parameters:', {
            seed, maxIterations, updateFrequency, betaInit, betaFinal, kLambda,
            width: this.imageWidth, height: this.imageHeight
        });
        
        this.isRunning = true;
        this.startBtn.disabled = true;
        this.startBtn.textContent = 'PAINTING...';
        this.progressSection.style.display = 'block';
        this.canvasContainer.style.display = 'flex';
        this.statsSection.style.display = 'grid';
        
        // Initialize progress
        this.updateProgress(0, maxIterations);
        this.updateStats(0, 0, Infinity, 0);
        
        // Start MCMC simulation
        this.startMCMC(seed, maxIterations, updateFrequency, betaInit, betaFinal, kLambda);
    }
    
    async loadWebAssembly() {
        try {
            console.log('Loading MCMC Painter WebAssembly module...');
            
            // Check if module file exists
            const moduleCheck = await fetch('mcmc_module.js');
            if (!moduleCheck.ok) {
                throw new Error('WASM module not compiled. Run: ./build.sh');
            }
            
            // Dynamically load the Emscripten-generated module
            const script = document.createElement('script');
            script.src = 'mcmc_module.js';
            document.head.appendChild(script);
            
            // Wait for the module to be ready
            await new Promise((resolve, reject) => {
                const checkModule = setInterval(() => {
                    if (typeof MCMCModule !== 'undefined') {
                        clearInterval(checkModule);
                        MCMCModule().then(module => {
                            this.wasmModule = module;
                            console.log('✅ MCMC Painter WebAssembly module loaded!');
                            this.showSuccess('MCMC engine ready! Click LOTUS or upload an image to start.');
                            resolve();
                        }).catch(reject);
                    }
                }, 100);
                
                // Timeout after 10 seconds
                setTimeout(() => {
                    clearInterval(checkModule);
                    reject(new Error('Module loading timeout'));
                }, 10000);
            });
            
        } catch (error) {
            console.error('Failed to load WebAssembly:', error);
            this.showError(
                '⚠️ WASM module not found!\n\n' +
                'Build it by running: ./build.sh\n\n' +
                'This will auto-install Emscripten if needed.'
            );
            this.wasmModule = null;
        }
    }
    
    startMCMC(seed, maxIterations, updateFrequency, betaInit, betaFinal, kLambda) {
        if (!this.wasmModule) {
            this.showError('WebAssembly module not loaded. Please refresh the page.');
            this.finishPainting();
            return;
        }
        
        try {
            // Create MCMC painter instance
            this.mcmcPainter = new this.wasmModule.MCMCPainter();
            
            // Set seed
            this.mcmcPainter.setSeed(seed);
            console.log('Set seed:', seed);
            
            // Convert JS array to Emscripten vector
            const imageVec = new this.wasmModule.DoubleVector();
            for (let i = 0; i < this.imageData.length; i++) {
                imageVec.push_back(this.imageData[i]);
            }
            
            // Initialize with image data
            this.mcmcPainter.initialize(this.imageWidth, this.imageHeight, imageVec);
            console.log('Initialized MCMC painter with image data');
            
            // Clean up the temporary vector
            imageVec.delete();
            
            // Set parameters
            this.mcmcPainter.setParameters(betaInit, betaFinal, kLambda);
            console.log('Set parameters:', {betaInit, betaFinal, kLambda});
            
            // Show initial white canvas
            this.updateCanvasFromWasm();
            
            // Run MCMC
            this.runRealMCMC(maxIterations, updateFrequency);
            
        } catch (error) {
            console.error('Error starting MCMC:', error);
            this.showError('Failed to start MCMC: ' + error.message);
            this.finishPainting();
        }
    }
    
    runRealMCMC(maxIterations, updateFrequency) {
        let currentIteration = 0;
        let stepsSinceUpdate = 0;
        const startTime = Date.now();
        
        const mcmcStep = () => {
            if (currentIteration >= maxIterations || !this.isRunning) {
                const elapsed = (Date.now() - startTime) / 1000;
                console.log(`Completed ${currentIteration} iterations in ${elapsed.toFixed(1)}s`);
                this.finishPainting();
                return;
            }
            
            try {
                // Run one MCMC step
                const accepted = this.mcmcPainter.mcmcStep(currentIteration, maxIterations);
                currentIteration++;
                stepsSinceUpdate++;
                
                // Update display every updateFrequency steps
                if (stepsSinceUpdate >= updateFrequency) {
                    const currentSSE = this.mcmcPainter.getCurrentSSE();
                    const bestSSE = this.mcmcPainter.getBestSSE();
                    const linesCount = this.mcmcPainter.getLinesCount();
                    
                    this.updateProgress(currentIteration, maxIterations);
                    this.updateStats(currentIteration, currentSSE, bestSSE, linesCount);
                    this.updateCanvasFromWasm();
                    
                    stepsSinceUpdate = 0;
                    
                    // Log progress
                    if (currentIteration % (updateFrequency * 5) === 0) {
                        const elapsed = (Date.now() - startTime) / 1000;
                        const rate = currentIteration / elapsed;
                        console.log(`Iter ${currentIteration}/${maxIterations}: K=${linesCount}, SSE=${Math.round(bestSSE)}, Rate=${rate.toFixed(1)} it/s`);
                    }
                }
                
                // Continue immediately (no artificial delay)
                // Use setTimeout(0) to avoid blocking the browser
                setTimeout(mcmcStep, 0);
                
            } catch (error) {
                console.error('Error in MCMC step:', error);
                this.showError('Error during painting: ' + error.message);
                this.finishPainting();
            }
        };
        
        // Start the loop
        mcmcStep();
    }
    
    updateCanvasFromWasm() {
        if (!this.mcmcPainter) return;
        
        try {
            const canvasVec = this.mcmcPainter.getCurrentCanvas();
            const ctx = this.paintedCtx;
            const canvasElement = this.paintedCanvas;
            
            // Get actual dimensions from WASM
            const wasmWidth = this.mcmcPainter.getWidth();
            const wasmHeight = this.mcmcPainter.getHeight();
            
            // Create ImageData
            const imageData = ctx.createImageData(canvasElement.width, canvasElement.height);
            const data = imageData.data;
            
            // Scale factors
            const scaleX = wasmWidth / canvasElement.width;
            const scaleY = wasmHeight / canvasElement.height;
            
            // Draw pixels with scaling
            for (let y = 0; y < canvasElement.height; y++) {
                for (let x = 0; x < canvasElement.width; x++) {
                    const srcY = Math.min(Math.floor(y * scaleY), wasmHeight - 1);
                    const srcX = Math.min(Math.floor(x * scaleX), wasmWidth - 1);
                    
                    const pixelIndex = (y * canvasElement.width + x) * 4;
                    const srcIndex = (srcY * wasmWidth + srcX) * 3;
                    
                    // Access vector elements using .get()
                    data[pixelIndex] = Math.floor(canvasVec.get(srcIndex) * 255);     // R
                    data[pixelIndex + 1] = Math.floor(canvasVec.get(srcIndex + 1) * 255); // G
                    data[pixelIndex + 2] = Math.floor(canvasVec.get(srcIndex + 2) * 255); // B
                    data[pixelIndex + 3] = 255; // A
                }
            }
            
            ctx.putImageData(imageData, 0, 0);
            
            // Clean up the vector
            canvasVec.delete();
            
        } catch (error) {
            console.error('Error updating canvas:', error);
        }
    }
    
    updateProgress(current, total) {
        const percentage = (current / total) * 100;
        this.progressFill.style.width = `${percentage}%`;
        this.progressText.textContent = `${current} / ${total} iterations`;
    }
    
    updateStats(iteration, currentSSE, bestSSE, lines) {
        document.getElementById('currentIteration').textContent = iteration;
        document.getElementById('currentSSE').textContent = Math.round(currentSSE);
        document.getElementById('bestSSE').textContent = Math.round(bestSSE);
        document.getElementById('elementsCount').textContent = lines;
    }
    
    finishPainting() {
        this.isRunning = false;
        this.startBtn.disabled = false;
        this.startBtn.textContent = 'START';
        this.showSuccess('Painting completed! Check out your artistic creation.');
        
        // Clean up
        if (this.mcmcPainter) {
            try {
                this.mcmcPainter.delete();
            } catch (e) {
                // Ignore cleanup errors
            }
            this.mcmcPainter = null;
        }
    }
    
    showError(message) {
        this.errorMessage.textContent = message;
        this.errorMessage.style.display = 'block';
        this.successMessage.style.display = 'none';
    }
    
    showSuccess(message) {
        this.successMessage.textContent = message;
        this.successMessage.style.display = 'block';
        this.errorMessage.style.display = 'none';
    }
    
    hideMessages() {
        this.errorMessage.style.display = 'none';
        this.successMessage.style.display = 'none';
    }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    new MCMCPainterApp();
});
