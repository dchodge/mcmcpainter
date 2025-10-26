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
        // Canvas elements
        this.originalCanvas = document.getElementById('originalCanvas');
        this.paintedCanvas = document.getElementById('paintedCanvas');
        this.originalCtx = this.originalCanvas.getContext('2d');
        this.paintedCtx = this.paintedCanvas.getContext('2d');
        
        // UI elements
        this.imageInput = document.getElementById('imageInput');
        this.startBtn = document.getElementById('startBtn');
        this.progressSection = document.getElementById('progressSection');
        this.progressFill = document.getElementById('progressFill');
        this.progressText = document.getElementById('progressText');
        this.messageArea = document.getElementById('messageArea');
        
        // Stats elements
        this.currentIteration = document.getElementById('currentIteration');
        this.linesCount = document.getElementById('linesCount');
        this.currentSSE = document.getElementById('currentSSE');
        this.bestSSE = document.getElementById('bestSSE');
        
        // Dropdown elements
        this.imageDropdownBtn = document.getElementById('imageDropdownBtn');
        this.imageDropdown = document.getElementById('imageDropdown');
        this.imageDropdownText = document.getElementById('imageDropdownText');
        this.configDropdownBtn = document.getElementById('configDropdownBtn');
        this.configDropdown = document.getElementById('configDropdown');
        this.configDropdownText = document.getElementById('configDropdownText');
        this.mathDropdownBtn = document.getElementById('mathDropdownBtn');
        this.mathDropdown = document.getElementById('mathDropdown');
        this.mathDropdownText = document.getElementById('mathDropdownText');
        
        // Advanced controls
        this.advancedToggle = document.getElementById('advancedToggle');
        this.advancedControls = document.getElementById('advancedControls');
    }
    
    setupEventListeners() {
        // Image dropdown
        this.imageDropdownBtn.addEventListener('click', () => this.toggleDropdown('image'));
        this.imageDropdown.addEventListener('click', (e) => this.handleImageSelection(e));
        
        // Config dropdown
        this.configDropdownBtn.addEventListener('click', () => this.toggleDropdown('config'));
        this.configDropdown.addEventListener('click', (e) => this.handleConfigSelection(e));
        
        // Math dropdown
        this.mathDropdownBtn.addEventListener('click', () => this.toggleDropdown('math'));
        this.mathDropdown.addEventListener('click', (e) => this.handleMathSelection(e));
        
        // Advanced controls toggle
        this.advancedToggle.addEventListener('click', () => this.toggleAdvancedControls());
        
        // File input
        this.imageInput.addEventListener('change', (e) => this.handleFileSelect(e));
        
        // Start button
        this.startBtn.addEventListener('click', () => this.startPainting());
        
        // Drag and drop
        document.addEventListener('dragover', (e) => this.handleDragOver(e));
        document.addEventListener('dragleave', (e) => this.handleDragLeave(e));
        document.addEventListener('drop', (e) => this.handleDrop(e));
        
        // Close dropdowns when clicking outside
        document.addEventListener('click', (e) => this.handleOutsideClick(e));
    }
    
    toggleDropdown(type) {
        let dropdown, btn;
        
        if (type === 'image') {
            dropdown = this.imageDropdown;
            btn = this.imageDropdownBtn;
        } else if (type === 'config') {
            dropdown = this.configDropdown;
            btn = this.configDropdownBtn;
        } else if (type === 'math') {
            dropdown = this.mathDropdown;
            btn = this.mathDropdownBtn;
        }
        
        // Close other dropdowns
        this.imageDropdown.classList.remove('show');
        this.imageDropdownBtn.classList.remove('active');
        this.configDropdown.classList.remove('show');
        this.configDropdownBtn.classList.remove('active');
        this.mathDropdown.classList.remove('show');
        this.mathDropdownBtn.classList.remove('active');
        
        // Toggle current dropdown
        const isOpen = dropdown.classList.contains('show');
        if (isOpen) {
            dropdown.classList.remove('show');
            btn.classList.remove('active');
        } else {
            dropdown.classList.add('show');
            btn.classList.add('active');
        }
    }
    
    handleImageSelection(e) {
        const item = e.target.closest('.dropdown-item');
        if (!item) return;
        
        const action = item.dataset.action;
        
        switch (action) {
            case 'lotus':
            case 'vi_leigh':
            case 'octopus':
                this.useDefaultImage(action);
                this.imageDropdownText.textContent = item.querySelector('.image-name').textContent;
                break;
            case 'upload':
                this.imageInput.click();
                this.imageDropdownText.textContent = 'Choose File';
                break;
            case 'dragdrop':
                this.showMessage('Drag and drop a PNG file anywhere on the page', 'success');
                this.imageDropdownText.textContent = 'Drag & Drop';
                break;
        }
        
        this.imageDropdown.classList.remove('show');
        this.imageDropdownBtn.classList.remove('active');
    }
    
    handleConfigSelection(e) {
        const item = e.target.closest('.dropdown-item');
        if (!item) return;
        
        const preset = item.dataset.preset;
        this.applyPreset(preset);
        this.configDropdownText.textContent = item.querySelector('.preset-name').textContent;
        
        this.configDropdown.classList.remove('show');
        this.configDropdownBtn.classList.remove('active');
    }
    
    handleMathSelection(e) {
        const item = e.target.closest('.dropdown-item');
        if (!item) return;
        
        const mathType = item.dataset.math;
        this.showMathSection(mathType);
        this.mathDropdownText.textContent = item.querySelector('.math-name').textContent;
        
        this.mathDropdown.classList.remove('show');
        this.mathDropdownBtn.classList.remove('active');
    }
    
    showMathSection(mathType) {
        // Hide all math sections
        const sections = ['mathOverview', 'mathRJMCMC', 'mathProposals', 'mathAcceptance'];
        sections.forEach(section => {
            document.getElementById(section).style.display = 'none';
        });
        
        // Show selected section
        const sectionMap = {
            'overview': 'mathOverview',
            'rj-mcmc': 'mathRJMCMC',
            'proposals': 'mathProposals',
            'acceptance': 'mathAcceptance'
        };
        
        if (sectionMap[mathType]) {
            document.getElementById(sectionMap[mathType]).style.display = 'block';
        }
    }
    
    applyPreset(preset) {
        const presets = {
            quick: { iterations: 5000, updateFreq: 50 },
            standard: { iterations: 50000, updateFreq: 100 },
            high: { iterations: 100000, updateFreq: 100 },
            custom: { iterations: 100000, updateFreq: 100 }
        };
        
        const config = presets[preset];
        if (config) {
            document.getElementById('maxIterations').value = config.iterations;
            document.getElementById('updateFrequency').value = config.updateFreq;
        }
    }
    
    toggleAdvancedControls() {
        this.advancedControls.style.display = this.advancedControls.style.display === 'none' ? 'block' : 'none';
        this.advancedToggle.classList.toggle('active');
    }
    
    handleOutsideClick(e) {
        // Close dropdowns when clicking outside
        if (!e.target.closest('.dropdown')) {
            this.imageDropdown.classList.remove('show');
            this.imageDropdownBtn.classList.remove('active');
            this.configDropdown.classList.remove('show');
            this.configDropdownBtn.classList.remove('active');
        }
    }
    
    handleDragOver(e) {
        e.preventDefault();
        document.body.classList.add('dragover');
    }
    
    handleDragLeave(e) {
        e.preventDefault();
        if (!e.relatedTarget || !document.body.contains(e.relatedTarget)) {
            document.body.classList.remove('dragover');
        }
    }
    
    handleDrop(e) {
        e.preventDefault();
        document.body.classList.remove('dragover');
        
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
        // Validate PNG file
        if (!file.name.toLowerCase().endsWith('.png')) {
            this.showError('Please select a PNG file only.');
            return;
        }
        
        try {
            const img = await this.loadImageFromFile(file);
            this.processImage(img);
            this.showMessage(`Loaded: ${file.name}`, 'success');
        } catch (error) {
            console.error('Error processing file:', error);
            this.showError('Failed to process PNG file. Please try again.');
        }
    }
    
    loadImageFromFile(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => resolve(img);
            img.onerror = reject;
            img.src = URL.createObjectURL(file);
        });
    }
    
    async useDefaultImage(imageName = 'lotus') {
        try {
            const imageNames = {
                'lotus': 'Lotus',
                'vi_leigh': 'Vivien Leigh',
                'octopus': 'Octopus'
            };
            
            const response = await fetch(`public/${imageName}.png`);
            if (!response.ok) {
                throw new Error(`Failed to load ${imageNames[imageName]} image`);
            }
            
            const blob = await response.blob();
            const img = await this.loadImageFromBlob(blob);
            this.processImage(img);
            this.showMessage(`Loaded: ${imageNames[imageName]}`, 'success');
            
        } catch (error) {
            console.error('Error loading default image:', error);
            this.showError('Failed to load default image. Please upload your own image.');
        }
    }
    
    loadImageFromBlob(blob) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => resolve(img);
            img.onerror = reject;
            img.src = URL.createObjectURL(blob);
        });
    }
    
    processImage(img) {
        const maxDim = parseInt(document.getElementById('maxDimension').value) || 800;
        const scale = Math.min(maxDim / Math.max(img.width, img.height), 1);
        this.imageWidth = Math.round(img.width * scale);
        this.imageHeight = Math.round(img.height * scale);
        
        const tempCanvas = document.createElement('canvas');
        tempCanvas.width = this.imageWidth;
        tempCanvas.height = this.imageHeight;
        const tempCtx = tempCanvas.getContext('2d');
        tempCtx.drawImage(img, 0, 0, this.imageWidth, this.imageHeight);
        
        const imgData = tempCtx.getImageData(0, 0, this.imageWidth, this.imageHeight);
        
        this.imageData = [];
        for (let y = 0; y < this.imageHeight; y++) {
            for (let x = 0; x < this.imageWidth; x++) {
                const idx = (y * this.imageWidth + x) * 4;
                this.imageData.push(
                    imgData.data[idx] / 255,
                    imgData.data[idx + 1] / 255,
                    imgData.data[idx + 2] / 255
                );
            }
        }
        
        this.setupCanvases(img);
        this.currentImage = img;
        this.startBtn.disabled = false;
        
        console.log(`Image processed: ${this.imageWidth}×${this.imageHeight}px`);
    }
    
    setupCanvases(img) {
        const maxDisplay = 400;
        const scale = Math.min(maxDisplay / this.imageWidth, maxDisplay / this.imageHeight);
        const displayWidth = Math.round(this.imageWidth * scale);
        const displayHeight = Math.round(this.imageHeight * scale);
        
        this.originalCanvas.width = displayWidth;
        this.originalCanvas.height = displayHeight;
        this.paintedCanvas.width = displayWidth;
        this.paintedCanvas.height = displayHeight;
        
        this.originalCtx.drawImage(img, 0, 0, displayWidth, displayHeight);
        
        this.paintedCtx.fillStyle = 'white';
        this.paintedCtx.fillRect(0, 0, displayWidth, displayHeight);
    }
    
    clearImage() {
        this.currentImage = null;
        this.startBtn.disabled = true;
        this.imageDropdownText.textContent = 'Choose Image Source';
        this.imageInput.value = '';
    }
    
    async loadWebAssembly() {
        try {
            console.log('Loading WebAssembly module...');
            
            // Load the WASM module dynamically
            const script = document.createElement('script');
            script.src = 'mcmc_module.js';
            script.onload = () => {
                if (typeof MCMCModule !== 'undefined') {
                    MCMCModule().then((module) => {
                        this.wasmModule = module;
                        console.log('WebAssembly module loaded successfully');
                    }).catch((error) => {
                        console.error('Error initializing WASM module:', error);
                        this.showError('Failed to initialize WebAssembly module. Please refresh the page.');
                    });
                } else {
                    console.error('MCMCModule not found');
                    this.showError('WebAssembly module not found. Please run: npm run build-wasm');
                }
            };
            script.onerror = () => {
                console.error('Failed to load WASM script');
                this.showError('Failed to load WebAssembly module. Please run: npm run build-wasm');
            };
            document.head.appendChild(script);
            
        } catch (error) {
            console.error('Error loading WebAssembly:', error);
            this.showError('Failed to load WebAssembly: ' + error.message);
        }
    }
    
    startPainting() {
        if (!this.currentImage || this.isRunning || !this.wasmModule) return;
        
        const seed = 42;
        const maxIterations = parseInt(document.getElementById('maxIterations').value) || 100000;
        const updateFrequency = parseInt(document.getElementById('updateFrequency').value) || 100;
        const betaInit = parseFloat(document.getElementById('betaInit').value) || 0.1;
        const betaFinal = parseFloat(document.getElementById('betaFinal').value) || 2.0;
        let kLambda = parseFloat(document.getElementById('kLambda').value) || 0;
        
        if (kLambda === 0) {
            kLambda = 0.5 * this.imageWidth;
        }
        
        this.isRunning = true;
        this.startBtn.disabled = true;
        this.startBtn.textContent = 'Painting...';
        this.progressSection.style.display = 'block';
        
        this.startMCMC(seed, maxIterations, updateFrequency, betaInit, betaFinal, kLambda);
    }
    
    async startMCMC(seed, maxIterations, updateFrequency, betaInit, betaFinal, kLambda) {
        try {
            this.mcmcPainter = new this.wasmModule.MCMCPainter();
            
            this.mcmcPainter.setSeed(seed);
            console.log('Set seed:', seed);
            
            const imageVec = new this.wasmModule.DoubleVector();
            for (let i = 0; i < this.imageData.length; i++) {
                imageVec.push_back(this.imageData[i]);
            }
            
            this.mcmcPainter.initialize(this.imageWidth, this.imageHeight, imageVec);
            console.log('Initialized MCMC painter with image data');
            
            imageVec.delete();
            
            this.mcmcPainter.setParameters(betaInit, betaFinal, kLambda);
            console.log('Set parameters:', {betaInit, betaFinal, kLambda});
            
            this.updateCanvasFromWasm();
            
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
                const accepted = this.mcmcPainter.mcmcStep(currentIteration, maxIterations);
                currentIteration++;
                stepsSinceUpdate++;
                
                if (stepsSinceUpdate >= updateFrequency) {
                    const currentSSE = this.mcmcPainter.getCurrentSSE();
                    const bestSSE = this.mcmcPainter.getBestSSE();
                    const linesCount = this.mcmcPainter.getLinesCount();
                    
                    this.updateProgress(currentIteration, maxIterations);
                    this.updateStats(currentIteration, currentSSE, bestSSE, linesCount);
                    this.updateCanvasFromWasm();
                    
                    stepsSinceUpdate = 0;
                    
                    if (currentIteration % (updateFrequency * 5) === 0) {
                        const elapsed = (Date.now() - startTime) / 1000;
                        const rate = currentIteration / elapsed;
                        console.log(`Iter ${currentIteration}/${maxIterations}: K=${linesCount}, SSE=${Math.round(bestSSE)}, Rate=${rate.toFixed(1)} it/s`);
                    }
                }
                
                requestAnimationFrame(mcmcStep);
                
            } catch (error) {
                console.error('Error during painting:', error);
                this.showError('Error during painting: ' + error.message);
                this.finishPainting();
            }
        };
        
        mcmcStep();
    }
    
    updateCanvasFromWasm() {
        if (!this.mcmcPainter) return;
        
        try {
            const canvasVec = this.mcmcPainter.getCurrentCanvas();
            const ctx = this.paintedCtx;
            const canvasElement = this.paintedCanvas;
            
            const wasmWidth = this.mcmcPainter.getWidth();
            const wasmHeight = this.mcmcPainter.getHeight();
            
            const imageData = ctx.createImageData(canvasElement.width, canvasElement.height);
            const data = imageData.data;
            
            const scaleX = wasmWidth / canvasElement.width;
            const scaleY = wasmHeight / canvasElement.height;
            
            for (let y = 0; y < canvasElement.height; y++) {
                for (let x = 0; x < canvasElement.width; x++) {
                    const srcY = Math.min(Math.floor(y * scaleY), wasmHeight - 1);
                    const srcX = Math.min(Math.floor(x * scaleX), wasmWidth - 1);
                    
                    const pixelIndex = (y * canvasElement.width + x) * 4;
                    const srcIndex = (srcY * wasmWidth + srcX) * 3;
                    
                    data[pixelIndex] = Math.floor(canvasVec.get(srcIndex) * 255);
                    data[pixelIndex + 1] = Math.floor(canvasVec.get(srcIndex + 1) * 255);
                    data[pixelIndex + 2] = Math.floor(canvasVec.get(srcIndex + 2) * 255);
                    data[pixelIndex + 3] = 255;
                }
            }
            
            ctx.putImageData(imageData, 0, 0);
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
    
    updateStats(current, currentSSE, bestSSE, linesCount) {
        this.currentIteration.textContent = current.toLocaleString();
        this.linesCount.textContent = linesCount;
        this.currentSSE.textContent = Math.round(currentSSE).toLocaleString();
        this.bestSSE.textContent = Math.round(bestSSE).toLocaleString();
    }
    
    finishPainting() {
        this.isRunning = false;
        this.startBtn.disabled = false;
        this.startBtn.textContent = 'Start Painting';
        this.showMessage('Painting completed!', 'success');
    }
    
    showMessage(message, type = 'success') {
        const messageDiv = document.createElement('div');
        messageDiv.className = `${type}-message`;
        messageDiv.textContent = message;
        
        this.messageArea.innerHTML = '';
        this.messageArea.appendChild(messageDiv);
        
        setTimeout(() => {
            messageDiv.remove();
        }, 5000);
    }
    
    showError(message) {
        this.showMessage(message, 'error');
    }
}

// Initialize the app when the page loads
document.addEventListener('DOMContentLoaded', () => {
    new MCMCPainterApp();
});

// Add drag and drop styles
const style = document.createElement('style');
style.textContent = `
    body.dragover {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
    }
    
    body.dragover::before {
        content: 'Drop image file here';
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: rgba(255, 255, 255, 0.9);
        padding: 20px 40px;
        border-radius: 12px;
        font-size: 1.2em;
        font-weight: 500;
        color: #333;
        z-index: 1000;
        pointer-events: none;
    }
`;
document.head.appendChild(style);
