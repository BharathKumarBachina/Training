---
description: Scan for secrets, push the project to GitHub, deploy GitHub Pages via Actions, write the README, and set the repo About with the Pages link
argument-hint: <github-repo-url or owner/repo>
allowed-tools: Bash(git *), Bash(gh *), Bash(grep *), Bash(find *), Bash(ls *), Bash(cat *), Bash(curl *), Read, Write, Edit, Glob, Grep
---

# Publish this project to GitHub

Target repository: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and ask the user for the GitHub repository URL (for example `https://github.com/owner/repo.git`) or `owner/repo`. Do not guess a repository.

Normalise the target into `OWNER`, `REPO` and `REMOTE_URL` (`https://github.com/OWNER/REPO.git`). Work through the steps below **in order**. Step 1 is a gate: never push if it fails. Report what you did at each step, and finish with the live GitHub Pages URL.

## Step 1 — Scan for sensitive data (gate, must pass before any push)

1. Confirm `gh auth status` shows a logged-in account. If not, tell the user to run `! gh auth login` and stop.
2. Make sure a `.gitignore` exists and covers at least: `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `node_modules/`, `.DS_Store`, `venv/`, `__pycache__/`, `*.log`, and any IDE folders. Create or extend it if needed. Never ignore `.claude/` — the project commands should be versioned.
3. Scan every file that would be committed (`git ls-files --cached --others --exclude-standard`, or all files if git is not initialised yet) for secrets. Use `grep -rniE` with at least these patterns, skipping `.git/`, `node_modules/` and binaries:
   - API keys and tokens: `api[_-]?key`, `secret`, `token`, `password`, `passwd`, `AKIA[0-9A-Z]{16}` (AWS), `sk-[A-Za-z0-9]{20,}` (OpenAI), `sk-ant-` (Anthropic), `ghp_[A-Za-z0-9]{30,}` / `gho_` / `github_pat_` (GitHub), `xox[baprs]-` (Slack), `AIza[0-9A-Za-z_-]{35}` (Google), `-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----`
   - Connection strings: `mongodb(\+srv)?://`, `postgres(ql)?://`, `mysql://`, `redis://`, `amqp://` with credentials in them
   - Personal data that should not be public: NRIC / FIN numbers (`[STFGM][0-9]{7}[A-Z]`), phone numbers, private email addresses other than the repo owner's, and any real customer names or records.
   - Files by name: `.env*`, `*.pem`, `*.key`, `credentials.json`, `serviceAccount*.json`, `secrets.*`, `*.docx`/`*.xlsx`/`*.pdf` that look like assessments, forms or personal documents.
4. Review each hit. Placeholders such as `YOUR_EMAIL@example.com`, `YOUR_API_KEY` or obvious demo values are fine. For anything real:
   - Do **not** push. List the file and line to the user, and either remove the value, replace it with a placeholder/environment variable, or add the file to `.gitignore`. If it was already committed earlier, tell the user it also needs rotating and rewriting out of history.
   - Personal documents (assessment forms, ID scans) go into `.gitignore`, not into the repo.
5. State clearly: "Secret scan: PASS" (with what was checked) or "Secret scan: FAIL" (with findings). Only continue on PASS.

## Step 2 — Upload the code to GitHub

1. If the directory is not a git repository, run `git init -b main`. Otherwise keep the current branch.
2. Set the commit identity **for this repository only** (`git config user.name` / `user.email`) from the user's GitHub account if it is not already set — never change the global config.
3. Check the remote with `git ls-remote --heads REMOTE_URL`:
   - Repo does not exist → create it with `gh repo create OWNER/REPO --public --source=. --remote=origin` (ask the user first if it should be private).
   - Repo exists and is empty → `git remote add origin REMOTE_URL` (or `git remote set-url origin REMOTE_URL`).
   - Repo exists with commits → add the remote, `git fetch origin`, and if the local history is unrelated, `git pull --rebase origin main --allow-unrelated-histories` before pushing. Never force-push.
4. Stage and commit everything that passed the scan. Use a clear commit message describing the project. End commit messages with the attribution lines required by the current session.
5. `git push -u origin <branch>`. If it fails with 403, `gh api repos/OWNER/REPO --jq .permissions` and tell the user which account lacks push rights; do not retry with tricks.

## Step 3 — Create or update GitHub Pages via GitHub Actions

1. Detect the site type:
   - Static HTML at the root (an `index.html` exists) → deploy the repository root.
   - A build step (`package.json` with a build script, `dist/`, `build/`, `_site/`) → run the build in the workflow and deploy its output folder. Use `npm ci && npm run build` for Node projects.
2. Create or update `.github/workflows/deploy-pages.yml` using the official Pages actions (`actions/checkout@v4`, `actions/configure-pages@v5`, `actions/upload-pages-artifact@v3`, `actions/deploy-pages@v4`) with `permissions: pages: write, id-token: read, contents: read`, triggered on `push` to the default branch and `workflow_dispatch`, and a `github-pages` environment. For a static root site upload `path: .`; for a built site upload the build output path. Add `concurrency: group: pages, cancel-in-progress: false`.
3. Point Pages at the workflow: `gh api -X POST repos/OWNER/REPO/pages -f build_type=workflow` (if Pages already exists use `-X PUT`). This replaces any "deploy from branch" setting.
4. Commit and push the workflow, then wait for the run: `gh run watch` (or poll `gh run list --workflow=deploy-pages.yml --limit 1`). Read the Pages URL with `gh api repos/OWNER/REPO/pages --jq .html_url` and confirm it returns HTTP 200 with `curl -s -o /dev/null -w "%{http_code}" URL`. If the run fails, read the log with `gh run view --log-failed`, fix the workflow, and push again.

## Step 4 — Create or update README.md

If `README.md` does not exist, create it. If it exists, update it in place and keep any sections the user wrote. It must contain:

- Project title and a one-paragraph description of what the app does.
- **Live demo** link to the GitHub Pages URL from Step 3.
- How to run it locally (for a static site: open `index.html`; otherwise the install/run commands).
- Tech stack and key features (short bullets).
- Project structure (only the files that matter, not a full tree).
- Deployment section: "Deployed automatically to GitHub Pages by `.github/workflows/deploy-pages.yml` on every push to `main`."
- Any configuration the user must change (for example a form endpoint or API placeholder), without ever putting real secrets in the README.

Commit and push the README.

## Step 5 — Set the repository About and homepage

1. Write a one-sentence description of the project.
2. `gh repo edit OWNER/REPO --description "<description>" --homepage "<Pages URL>"`.
3. Optionally add topics that fit: `gh repo edit OWNER/REPO --add-topic <topic>` (for example `github-pages`, `vanilla-js`, `claude-code`).
4. Confirm with `gh repo view OWNER/REPO --json description,homepageUrl,url`.

## Final report

Reply with a short summary containing:

- Secret scan result and what was checked.
- Repository URL and the branch pushed.
- GitHub Pages URL and whether it returned 200.
- What changed in README.md and the About/homepage values.
- Anything skipped or blocked, and why.
