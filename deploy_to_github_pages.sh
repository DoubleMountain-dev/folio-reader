#!/bin/bash
# deploy_to_github_pages.sh
# Run this script from the root of your folio_reader project folder.
# Usage: bash deploy_to_github_pages.sh YOUR_GITHUB_USERNAME

USERNAME=$1

if [ -z "$USERNAME" ]; then
  echo "Usage: bash deploy_to_github_pages.sh YOUR_GITHUB_USERNAME"
  exit 1
fi

REPO_NAME="folio-reader"
GITHUB_URL="https://github.com/$USERNAME/$REPO_NAME.git"

echo ""
echo "========================================="
echo "  Folio Reader -- GitHub Pages Deploy"
echo "========================================="
echo ""

# Step 1: Build Flutter web
echo "[1/4] Building Flutter web release..."
flutter build web --release --base-href "/$REPO_NAME/"

if [ $? -ne 0 ]; then
  echo "Build failed. Fix errors and try again."
  exit 1
fi

echo "Build successful!"
echo ""

# Step 2: Go into build output
cd build/web

# Step 3: Init git and push to gh-pages branch
echo "[2/4] Setting up git in build/web..."
git init
git checkout -b gh-pages

echo "[3/4] Committing files..."
git add .
git commit -m "Deploy Folio Reader to GitHub Pages"

echo "[4/4] Pushing to GitHub..."
git remote add origin $GITHUB_URL
git push --force origin gh-pages

echo ""
echo "========================================="
echo "  DONE!"
echo "  Your app will be live at:"
echo "  https://$USERNAME.github.io/$REPO_NAME/"
echo ""
echo "  Note: GitHub Pages may take 1-2 minutes"
echo "  to become available after first deploy."
echo "========================================="
