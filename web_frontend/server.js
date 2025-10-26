const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('.'));
app.use('/public', express.static('public'));

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB limit
    },
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only image files are allowed!'), false);
        }
    }
});

// Routes
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Image processing endpoint
app.post('/api/process-image', upload.single('image'), async (req, res) => {
    try {
        console.log('Processing image request...');
        if (!req.file) {
            console.log('No file provided');
            return res.status(400).json({ error: 'No image file provided' });
        }

        console.log('File received:', req.file.originalname, 'Size:', req.file.size, 'Type:', req.file.mimetype);

        // Process image with Sharp
        const imageBuffer = req.file.buffer;
        const metadata = await sharp(imageBuffer).metadata();
        console.log('Image metadata:', metadata);
        
        // Check dimensions
        if (metadata.width > 800 || metadata.height > 800) {
            return res.status(400).json({ 
                error: `Image too large! Maximum size is 800x800 pixels. Your image is ${metadata.width}x${metadata.height}.` 
            });
        }

        // Resize if needed (maintain aspect ratio)
        let processedImage = sharp(imageBuffer);
        if (metadata.width > 800 || metadata.height > 800) {
            processedImage = processedImage.resize(800, 800, { 
                fit: 'inside',
                withoutEnlargement: true 
            });
            // Get new metadata after resize
            const resizedMetadata = await processedImage.metadata();
            metadata = resizedMetadata;
        }

        // Convert to RGB and get pixel data
        const { data, info } = await processedImage
            .raw()
            .toBuffer({ resolveWithObject: true });

        // Convert to 3D array format [height][width][rgb]
        const pixels = [];
        for (let y = 0; y < info.height; y++) {
            const row = [];
            for (let x = 0; x < info.width; x++) {
                const pixelIndex = (y * info.width + x) * info.channels;
                const pixel = [
                    data[pixelIndex] / 255.0,     // R
                    data[pixelIndex + 1] / 255.0, // G
                    data[pixelIndex + 2] / 255.0  // B
                ];
                row.push(pixel);
            }
            pixels.push(row);
        }

        res.json({
            success: true,
            width: info.width,
            height: info.height,
            pixels: pixels
        });

    } catch (error) {
        console.error('Image processing error:', error);
        res.status(500).json({ error: 'Failed to process image' });
    }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Error handling middleware
app.use((error, req, res, next) => {
    if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({ error: 'File too large. Maximum size is 5MB.' });
        }
    }
    
    console.error('Server error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
    console.log(`🎨 MCMC Painter Web Server running on http://localhost:${PORT}`);
    console.log(`📁 Serving files from: ${__dirname}`);
    console.log(`🚀 Ready for real-time artistic generation!`);
});

module.exports = app;
