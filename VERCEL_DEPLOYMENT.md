# Deploying MCMC Painter to Vercel

This guide will help you deploy your MCMC Painter web application to Vercel.

## Prerequisites

1. **Vercel Account**: Sign up at [vercel.com](https://vercel.com)
2. **GitHub Repository**: Your code should be in a GitHub repository
3. **Node.js**: For building the application

## Method 1: Deploy via Vercel Dashboard (Recommended)

### Step 1: Connect Your Repository
1. Go to [vercel.com/dashboard](https://vercel.com/dashboard)
2. Click **"New Project"**
3. Import your GitHub repository: `dchodge/mcmcpainter`
4. Click **"Import"**

### Step 2: Configure Build Settings
Vercel will automatically detect the configuration from `vercel.json`, but you can verify:

- **Framework Preset**: Other
- **Root Directory**: `./` (project root)
- **Build Command**: `cd web_frontend && npm install && npm run build-wasm`
- **Output Directory**: `web_frontend/web`
- **Install Command**: `cd web_frontend && npm install`

### Step 3: Deploy
1. Click **"Deploy"**
2. Vercel will automatically:
   - Install dependencies
   - Build the WASM module
   - Deploy your application

### Step 4: Access Your App
Your app will be available at: `https://your-project-name.vercel.app`

## Method 2: Deploy via Vercel CLI

### Step 1: Install Vercel CLI
```bash
npm install -g vercel
```

### Step 2: Login to Vercel
```bash
vercel login
```

### Step 3: Deploy
```bash
vercel
```

Follow the prompts:
- **Set up and deploy?** Yes
- **Which scope?** Your username
- **Link to existing project?** No
- **What's your project's name?** mcmc-painter
- **In which directory is your code located?** ./

### Step 4: Production Deploy
```bash
vercel --prod
```

## Configuration Details

### Vercel Configuration (`vercel.json`)
```json
{
  "version": 2,
  "buildCommand": "cd web_frontend && npm install && npm run build-wasm",
  "outputDirectory": "web_frontend/web",
  "installCommand": "cd web_frontend && npm install",
  "framework": null,
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Cross-Origin-Embedder-Policy",
          "value": "require-corp"
        },
        {
          "key": "Cross-Origin-Opener-Policy",
          "value": "same-origin"
        }
      ]
    },
    {
      "source": "/(.*\\.wasm)",
      "headers": [
        {
          "key": "Content-Type",
          "value": "application/wasm"
        }
      ]
    }
  ]
}
```

### Key Features:
- **WASM Support**: Proper headers for WebAssembly files
- **CORS Headers**: Required for WASM modules
- **Build Process**: Automatically compiles C++ to WASM
- **Static Hosting**: Optimized for frontend applications

## Troubleshooting

### WASM Module Not Loading
- Ensure Emscripten is available during build
- Check that `mcmc_module.js` and `mcmc_module.wasm` are generated
- Verify CORS headers are set correctly

### Build Failures
- Check that all dependencies are in `package.json`
- Ensure Node.js version compatibility
- Verify file paths in build commands

### Performance Issues
- WASM files are large (~2MB), consider:
  - Enabling compression
  - Using CDN for faster loading
  - Implementing progressive loading

## Environment Variables

If you need environment variables:
1. Go to your Vercel project dashboard
2. Click **Settings** → **Environment Variables**
3. Add any required variables

## Custom Domain

To use a custom domain:
1. Go to your Vercel project dashboard
2. Click **Settings** → **Domains**
3. Add your domain
4. Configure DNS settings with your domain provider

## Automatic Deployments

Vercel automatically deploys when you:
- Push to the main branch
- Create a pull request
- Merge a pull request

## Local Development

To test locally with Vercel:
```bash
vercel dev
```

This runs your application locally with Vercel's development server.

## Support

If you encounter issues:
1. Check the Vercel build logs
2. Verify all files are in the correct locations
3. Test locally first with `npm start`
4. Check browser developer tools for errors

## Benefits of Vercel

- **Fast Global CDN**: Your app loads quickly worldwide
- **Automatic HTTPS**: Secure by default
- **Preview Deployments**: Test changes before going live
- **Easy Rollbacks**: Revert to previous versions instantly
- **Analytics**: Built-in performance monitoring
- **Edge Functions**: Serverless functions if needed
