# Deploying Folio Reader to GitHub Pages

Follow these steps **exactly in order**.

---

## Step 1 — Create a GitHub repository

1. Go to **https://github.com/new**
2. Repository name: `folio-reader`
3. Set to **Public** (required for free GitHub Pages)
4. Do **NOT** check "Add README" or any other options
5. Click **Create repository**

---

## Step 2 — Build the Flutter web app

Open a terminal in the `folio_reader` project folder and run:

```bash
flutter build web --release --base-href "/folio-reader/"
```

> The `--base-href` flag must match your repository name exactly.
> If you named your repo something different, change `/folio-reader/` to `/your-repo-name/`.

Wait for the build to finish. It will create a `build/web/` folder.

---

## Step 3 — Push the build to GitHub

Run these commands **one by one** in your terminal:

```bash
cd build/web

git init
git checkout -b gh-pages
git add .
git commit -m "Deploy Folio Reader"
git remote add origin https://github.com/YOUR_USERNAME/folio-reader.git
git push --force origin gh-pages
```

Replace `YOUR_USERNAME` with your actual GitHub username.

---

## Step 4 — Enable GitHub Pages

1. Go to your repository on GitHub: `https://github.com/YOUR_USERNAME/folio-reader`
2. Click **Settings** (top menu)
3. Click **Pages** (left sidebar)
4. Under **Source**, select:
   - Branch: `gh-pages`
   - Folder: `/ (root)`
5. Click **Save**

---

## Step 5 — Open your app

After 1-2 minutes your app will be live at:

```
https://YOUR_USERNAME.github.io/folio-reader/
```

Share this link with your professor.

---

## Troubleshooting

**App shows blank page / 404**
- Make sure `--base-href "/folio-reader/"` matches your repo name exactly.
- Check that GitHub Pages source is set to `gh-pages` branch.

**"Permission denied" when pushing**
- GitHub may ask for your username and password (or personal access token).
- Create a token at: https://github.com/settings/tokens → Generate new token → check `repo` scope.

**Changes not showing after re-deploy**
- Run `flutter build web --release --base-href "/folio-reader/"` again.
- Then repeat Step 3 (the `cd build/web` and git commands).
- Hard refresh the browser: `Ctrl+Shift+R`

---

## For subsequent updates

Every time you change the code and want to update the live app:

```bash
flutter build web --release --base-href "/folio-reader/"
cd build/web
git init
git checkout -b gh-pages
git add .
git commit -m "Update Folio Reader"
git remote add origin https://github.com/YOUR_USERNAME/folio-reader.git
git push --force origin gh-pages
cd ../..
```

---

## No Firebase needed

This app does **not** use Firebase, so you do not need `firebase_options.dart`
or `firebase.json`. The app works entirely in the browser with no backend.
