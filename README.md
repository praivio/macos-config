# macos-config

macOS system setup: Homebrew packages, macOS defaults, and bootstrap orchestration for a fresh Mac. Dotfile management lives in the companion repo [praivio/macos-dotfiles](https://github.com/praivio/macos-dotfiles).

---

## How it works

| Repo | Handles |
|---|---|
| **macos-config** (this repo) | Homebrew packages, macOS defaults, fresh-machine bootstrap |
| **macos-dotfiles** | Shell config, git config, editor config — managed by chezmoi |

The two repos are linked via a git submodule: `dotfiles/` in this repo always points to a compatible commit of macos-dotfiles.

Packages are split into three Brewfiles: **common** (all machines), **work**, and **personal**. You choose your profile during bootstrap.

---

## Fresh machine setup

### Step 1 — Before running any script (manual, ~5 minutes)

**1a. Sign in with your Apple ID**
Open **System Settings → Apple ID**. Required for iCloud and the App Store.

**1b. Generate an SSH key**
```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

**1c. Add the SSH key to GitHub**
```bash
cat ~/.ssh/id_ed25519.pub   # copy this output
```
Then go to [github.com/settings/keys](https://github.com/settings/keys) → New SSH key → paste.

**1d. Add the key to ssh-agent**
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

**1e. Verify GitHub access**
```bash
ssh -T git@github.com
# Expected: "Hi praivio\! You've successfully authenticated..."
```

---

### Step 2 — Run bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/praivio/macos-config/main/bootstrap.sh | bash
```

The script will:

1. Confirm SSH access to GitHub (pauses if not set up)
2. Install **Xcode Command Line Tools**
3. Install **Rosetta 2** (Apple Silicon only)
4. Install **Homebrew**
5. Clone this repo to `~/.local/share/macos-config`
6. Ask you: **work** or **personal**?
7. Run `brew bundle` for common + profile-specific packages
8. Pause for **1Password CLI sign-in** (`op signin`) — needed for chezmoi secrets
9. Run `chezmoi init --apply` from [praivio/macos-dotfiles](https://github.com/praivio/macos-dotfiles)
10. Apply macOS system defaults

Total time: 20–40 minutes (Xcode and large casks take most of the time).

---

### Step 3 — After bootstrap (manual)

- **Restart your terminal** to pick up the new shell configuration
- **Sign into the Mac App Store** if not done, then re-run the Brewfiles to get `mas` apps:
  ```bash
  brew bundle --no-lock --file=~/.local/share/macos-config/Brewfile.common
  brew bundle --no-lock --file=~/.local/share/macos-config/Brewfile.work   # or Brewfile.personal
  ```
- **1Password SSH agent**: open 1Password → Settings → Developer → enable SSH agent
- **Configure secrets** in your dotfiles: see [macos-dotfiles README → Secrets](https://github.com/praivio/macos-dotfiles#secrets)
- **Restart** your Mac for all defaults to take full effect

---

## Day-to-day usage

### Adding or removing packages

Edit the appropriate Brewfile (`Brewfile.common`, `Brewfile.work`, or `Brewfile.personal`), commit, push, then on each machine:

```bash
brew bundle --no-lock --file=~/.local/share/macos-config/Brewfile.common
brew bundle --no-lock --file=~/.local/share/macos-config/Brewfile.work   # or personal
```

A convenience alias is available after dotfiles are applied:
```bash
brewup   # updates Homebrew + runs bundle for your profile
```

### Re-running macOS defaults

```bash
bash ~/.local/share/macos-config/scripts/apply-defaults.sh
```

### Updating the dotfiles submodule

When macos-dotfiles has new commits you want to pin to:
```bash
cd ~/.local/share/macos-config
git submodule update --remote dotfiles
git add dotfiles
git commit -m "chore: bump dotfiles submodule"
git push
```

---

## Repo structure

```
macos-config/
├── README.md
├── bootstrap.sh                  ← entry point for fresh machines
├── Brewfile.common               ← packages for all machines
├── Brewfile.work                 ← work-only packages
├── Brewfile.personal             ← personal-only packages
├── scripts/
│   └── apply-defaults.sh         ← macOS system preferences
└── dotfiles/                     ← git submodule → praivio/macos-dotfiles
```

---

## Machine profiles

| Package / App | work | personal |
|---|:---:|:---:|
| ansible, awscli, terraform | ✓ | — |
| cocoapods, dart, flutter | ✓ | — |
| android-studio, intellij-idea | ✓ | — |
| citrix-workspace, vagrant | ✓ | — |
| postgresql@14, postgresql@15 | ✓ | — |
| sshuttle, wrk | ✓ | — |
| anaconda | — | ✓ |
| calibre, gimp, musescore, vlc | — | ✓ |
| exercism, codecrafters | — | ✓ |
| Logic Pro (mas) | — | ✓ |
| Xcode (mas) | ✓ | ✓ |

---

## References

- [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle)
- [mas-cli](https://github.com/mas-cli/mas)
- [macOS defaults reference](https://macos-defaults.com)
- [praivio/macos-dotfiles](https://github.com/praivio/macos-dotfiles)
