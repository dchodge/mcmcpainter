# Deploying MCMC Painter to GitHub Pages

This guide will help you deploy the MCMC Painter web frontend to GitHub Pages.

## Prerequisites

1. **GitHub Repository**: Your code should be in a GitHub repository
2. **Emscripten**: Required for compiling the WASM module
3. **Node.js**: For building and deployment scripts

## Method 1: Automatic Deployment with GitHub Actions (Recommended)

### Step 1: Enable GitHub Pages
1. Go to your GitHub repository: `https://github.com/dchodge/mcmcpainter`
2. Click **Settings** → **Pages**
3. Under **Source**, select **GitHub Actions**
4. Save the settings

### Step 2: Push Your Code
The GitHub Actions workflow will automatically deploy when you push to the `main` branch:

```bash
git add .
git commit -m "Add GitHub Pages deployment"
git push origin main
```

### Step 3: Monitor Deployment
1. Go to **Actions** tab in your GitHub repository
2. Watch the "Deploy to GitHub Pages" workflow
3. Once complete, your app will be available at:
   `https://dchodge.github.io/mcmcpainter/`

## Method 2: Manual Deployment

### Step 1: Build the Application
```bash
cd web_frontend
npm install
npm run build-wasm
```

### Step 2: Create docs Directory
```bash
mkdir -p docs
```

### Step 3: Copy Files to docs
```bash
cp -r web_frontend/web/* docs/
```

### Step 4: Commit and Push
```bash
git add docs/
git commit -m "Deploy to GitHub Pages"
git push origin main
```

### Step 5: Enable GitHub Pages
1. Go to **Settings** → **Pages**
2. Under **Source**, select **Deploy from a branch**
3. Select **main** branch and **/docs** folder
4. Save settings

## Troubleshooting

### WASM Module Not Loading
- Ensure Emscripten is installed: `emsdk install latest && emsdk activate latest`
- Check that `mcmc_module.js` and `mcmc_module.wasm` are in the docs folder
- Verify file paths in the HTML are correct

### Images Not Loading
- Ensure all PNG files are copied to `docs/public/`
- Check that image paths in JavaScript are relative to the root

### CORS Issues
- GitHub Pages serves files over HTTPS
- Ensure all resources use relative paths
- Check browser console for specific error messages

## File Structure After Deployment

```
docs/
├── index.html
├── app.js
├── mcmc_module.js
├── mcmc_module.wasm
└── public/
    ├── lotus.png
    ├── vi_leigh.png
    └── octopus.png
```

## Custom Domain (Optional)

To use a custom domain:
1. Add a `CNAME` file to the docs folder with your domain
2. Update the GitHub Actions workflow to include the CNAME
3. Configure DNS settings with your domain provider

## Updating the Deployment

For automatic updates:
- Just push changes to the `main` branch
- GitHub Actions will rebuild and redeploy automatically

For manual updates:
- Run `npm run deploy` from the web_frontend directory
- Commit and push the updated docs folder

## Performance Tips

- The WASM module is large (~2MB), so consider:
  - Enabling compression on your web server
  - Using a CDN for faster loading
  - Implementing progressive loading

## Support

If you encounter issues:
1. Check the GitHub Actions logs
2. Verify all files are in the correct locations
3. Test locally first with `npm start`
4. Check browser developer tools for errors
