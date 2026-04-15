# macos-config

Automated macOS setup using [chezmoi](https://www.chezmoi.io/) for dotfile management and Homebrew for package installation. A single command brings a fresh Mac from zero to fully configured.

---

## What this does

| Layer | Tool | What gets managed |
|---|---|---|
| Dotfiles | chezmoi | `.zshrc`, `.gitconfig`, `.gitignore_global` |
| CLI tools & GUI apps | Homebrew + Brewfile | All packages, casks, taps |
| Mac App Store apps | `mas` (via Homebrew) | Logic Pro, Xcode, Bear, etc. |
| System preferences | `defaults write` script | Dock, Finder, keyboard, screenshots |
| Machine variants | chezmoi templates | Work vs personal package sets |

Packages are split into three sets: **common** (all machines), **work-only**, and **personal-only**. You choose your machine type the first time you run `chezmoi init`.

---

## Prerequisites

These steps must be completed manually on a fresh Mac before running the automated setup.

### 1. Sign in with your Apple ID

Open **System Settings → Apple ID** and sign in. This is needed for iCloud and for the Mac App Store.

### 2. Sign into the Mac App Store

Open the **App Store** app and sign in. The `mas` tool (which installs App Store apps automatically) requires an active session.

> **Note:** App Store apps can be installed after the fact. If you skip this, the Brewfile script will print a warning and continue — you can re-run `chezmoi apply` later once signed in.

### 3. Enable SSH (optional — needed for cloning via SSH)

If you want to use an SSH URL for the repo (recommended), ensure you have an SSH key and that it is added to your GitHub account. On a brand new machine you can also use HTTPS for the initial clone and switch to SSH afterwards.

To use HTTPS instead of SSH, edit `bootstrap.sh` and change the `CHEZMOI_REPO` line:
```bash
CHEZMOI_REPO="https://github.com/praivio/macos-config.git"
```

---

## Installation

### Option A — one-liner (recommended for fresh machines)

```bash
curl -fsSL https://raw.githubusercontent.com/praivio/macos-config/main/bootstrap.sh | bash
```

This script will:

1. Run any pending macOS software updates
2. Install **Xcode Command Line Tools** (prompts for your password)
3. Install **Homebrew**
4. Install **chezmoi** via Homebrew
5. Run `chezmoi init --apply` which:
   - Clones this repo to `~/.local/share/chezmoi`
   - Prompts you for your **machine type** (`work` or `personal`), **full name**, and **email**
   - Deploys dotfiles to `$HOME`
   - Runs `brew bundle` to install all packages and apps
   - Applies macOS system defaults

Total time: 20–40 minutes depending on your internet connection (Xcode and Logic Pro are large).

---

### Option B — manual step by step

Use this if you prefer to inspect each step or if the one-liner fails partway through.

**Step 1 — Install Xcode Command Line Tools**

```bash
xcode-select --install
```

A GUI dialog will appear. Click Install and wait for it to complete (~5 minutes).

**Step 2 — Install Homebrew**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, add Homebrew to your PATH (Apple Silicon):

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Step 3 — Install chezmoi**

```bash
brew install chezmoi
```

**Step 4 — Initialise chezmoi from this repo**

```bash
chezmoi init --apply git@github.com:praivio/macos-config.git
```

You will be prompted for:
- **Machine type:** `work` or `personal` — controls which packages are installed
- **Full name:** used in `~/.gitconfig`
- **Email address:** used in `~/.gitconfig`

These answers are stored in `~/.config/chezmoi/chezmoi.toml` and are never committed to the repo.

---

## Day-to-day usage

### Adding a new package

1. Edit the Brewfile section in `.chezmoiscripts/run_onchange_02-brew-packages.sh.tmpl`
2. Commit and push
3. On each machine: `chezmoi update` — this pulls the latest and re-runs the brew script automatically because its content changed

```bash
# shortcut (defined in .zshrc)
czu
```

### Editing dotfiles

```bash
chezmoi edit ~/.zshrc        # opens the source file in $EDITOR
chezmoi diff                 # preview what would change
chezmoi apply                # apply changes to $HOME
```

Or edit the source directory directly:

```bash
chezmoi cd                   # opens a shell in ~/.local/share/chezmoi
# edit files, then:
chezmoi apply
```

### Keeping packages up to date

```bash
# Update Homebrew and all installed packages
bup

# Pull latest dotfiles/scripts from GitHub and apply
czu
```

### Re-running macOS defaults

The defaults script runs only once per machine. To force it to run again (e.g. after editing it):

```bash
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

---

## Repo structure

```
macos-config/
├── README.md                              ← you are here
├── bootstrap.sh                           ← entry point for fresh machines
├── .chezmoi.toml.tmpl                     ← prompts for machine type, name, email
├── .chezmoiignore                         ← files chezmoi won't deploy to $HOME
│
├── .chezmoiscripts/
│   ├── run_once_before_01-install-homebrew.sh.tmpl   ← safety net: ensures brew is present
│   ├── run_onchange_02-brew-packages.sh.tmpl          ← all packages; re-runs on any change
│   └── run_once_after_03-macos-defaults.sh.tmpl       ← system preferences (runs once)
│
└── home/
    ├── dot_zshrc.tmpl                     ← ~/.zshrc (templated for work/personal)
    ├── dot_gitconfig.tmpl                 ← ~/.gitconfig (name/email from template vars)
    ├── dot_gitignore_global               ← ~/.gitignore_global
    └── README-post-install.md.tmpl        ← ~/README-post-install.md (manual checklist)
```

### Script naming conventions

chezmoi uses filename prefixes to control when scripts run:

| Prefix | Behaviour |
|---|---|
| `run_once_before_` | Runs once, before dotfiles are deployed |
| `run_onchange_` | Runs whenever the file's content changes |
| `run_once_after_` | Runs once, after dotfiles are deployed |

Numbers in the filenames (`01-`, `02-`, `03-`) control execution order within each group.

---

## Machine profiles

When you run `chezmoi init`, you choose `work` or `personal`. This controls:

| | Work | Personal |
|---|---|---|
| `citrix-workspace` | ✓ | — |
| `intellij-idea` | ✓ | — |
| `android-studio` | ✓ | — |
| `flutter`, `dart` | ✓ | — |
| `vagrant` | ✓ | — |
| `oracle-jdk`, `temurin` | ✓ | — |
| `postgresql@14` | ✓ | — |
| `sshuttle`, `wrk` | ✓ | — |
| `anaconda` | — | ✓ |
| Work git config include | ✓ | — |

To add a new work-only or personal-only package, find the appropriate `{{ if eq .machine "work" }}` block in `run_onchange_02-brew-packages.sh.tmpl` and add it there.

---

## Adding a new dotfile to chezmoi tracking

```bash
# Add an existing file to chezmoi source control
chezmoi add ~/.ssh/config

# Add and immediately make it a template (for machine-specific content)
chezmoi add --template ~/.ssh/config

# Check the result
chezmoi diff
chezmoi apply
```

---

## Secrets and sensitive files

**Do not commit secrets to this repo.** The recommended approach:

- Store secrets in **1Password** and use the [chezmoi 1Password integration](https://www.chezmoi.io/user-guide/password-managers/1password/) to inject them into templates at apply time
- Store machine-specific secrets in `~/.zshrc.local` (this file is sourced by `.zshrc` but is not tracked by chezmoi)

Example of injecting a secret from 1Password into a dotfile template:

```
export GITHUB_TOKEN="{{ onepasswordRead "op://Private/GitHub token/credential" }}"
```

---

## Troubleshooting

**`mas` fails with "Not signed in"**
Open the Mac App Store app, sign in, then re-run `chezmoi apply`. The brew script will skip already-installed packages.

**Homebrew not found after bootstrap**
Restart your terminal session, or run:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"    # Apple Silicon
# or
eval "$(/usr/local/bin/brew shellenv)"       # Intel
```

**A cask fails with "App already exists in /Applications"**
You may have manually installed an app that Homebrew now wants to manage. Either delete the existing app and re-run, or add `--adopt` to the relevant cask line.

**chezmoi apply fails on a template error**
Check your `~/.config/chezmoi/chezmoi.toml` — it should contain `machine`, `name`, and `email` keys. If it is missing or malformed, delete it and re-run `chezmoi init`.

**Re-running everything from scratch**
```bash
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

---

## Updating this repo from an existing machine

If you have made manual changes to your dotfiles and want to pull them back into the repo:

```bash
chezmoi re-add ~/.zshrc     # re-imports the live file into chezmoi source
chezmoi diff                # sanity check
chezmoi cd && git add -A && git commit -m "update zshrc" && git push
```

---

## References

- [chezmoi documentation](https://www.chezmoi.io/user-guide/)
- [chezmoi macOS guide](https://www.chezmoi.io/user-guide/machines/macos/)
- [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle)
- [mas-cli](https://github.com/mas-cli/mas)
- [macOS defaults reference](https://macos-defaults.com)
