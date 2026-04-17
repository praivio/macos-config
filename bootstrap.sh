#!/bin/bash
# =============================================================================
# bootstrap.sh — macOS setup entry point
#
# Usage on a fresh machine:
#   curl -fsSL https://raw.githubusercontent.com/praivio/macos-config/main/bootstrap.sh | bash
#
# Or clone first and run locally:
#   bash ~/.local/share/macos-config/bootstrap.sh
#
# Prerequisites (manual — do these before running this script):
#   1. Generate an SSH key and add it to GitHub — see README.md
#   2. Sign in with your Apple ID (System Settings → Apple ID)
#   3. Sign in to the Mac App Store
# =============================================================================
set -euo pipefail

MACOS_CONFIG_REPO="git@github.com:praivio/macos-config.git"
DOTFILES_REPO="git@github.com:praivio/macos-dotfiles.git"
MACOS_CONFIG_DIR="${HOME}/.local/share/macos-config"

# ── helpers ───────────────────────────────────────────────────────────────────
info()    { printf "\033[0;34m▶ %s\033[0m\n" "$*"; }
success() { printf "\033[0;32m✔ %s\033[0m\n" "$*"; }
warn()    { printf "\033[0;33m⚠ %s\033[0m\n" "$*"; }
die()     { printf "\033[0;31m✖ %s\033[0m\n" "$*" >&2; exit 1; }
ask()     { printf "\033[0;35m? %s\033[0m " "$*"; }

# ── architecture ──────────────────────────────────────────────────────────────
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
  warn "Intel Mac detected. Homebrew path: /usr/local"
fi

# ── banner ────────────────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║      macOS bootstrap — praivio/setup      ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

# ── preflight: SSH key check ──────────────────────────────────────────────────
info "Checking SSH access to GitHub..."
if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  echo ""
  warn "SSH to GitHub failed. Please ensure you have:"
  echo "  1. Generated an SSH key:  ssh-keygen -t ed25519 -C \"your@email.com\""
  echo "  2. Added it to GitHub:    https://github.com/settings/keys"
  echo "  3. Added it to ssh-agent: ssh-add ~/.ssh/id_ed25519"
  echo ""
  ask "Press Enter once your SSH key is set up, or Ctrl-C to abort..."
  read -r
  ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
    || die "Still can't reach GitHub via SSH. Aborting."
fi
success "SSH access to GitHub confirmed."

# ── 1. Xcode Command Line Tools ───────────────────────────────────────────────
if xcode-select -p &>/dev/null; then
  success "Xcode Command Line Tools already installed."
else
  info "Installing Xcode Command Line Tools..."
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  CLT=$(softwareupdate --list 2>/dev/null \
    | grep -E 'Command Line Tools for Xcode' \
    | sort -V | tail -1 \
    | sed 's/^[[:space:]]*\* //')
  softwareupdate --install "${CLT}" --agree-to-license
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  success "Xcode Command Line Tools installed."
fi

# ── 2. Rosetta 2 (Apple Silicon only) ────────────────────────────────────────
if [[ "$ARCH" == "arm64" ]]; then
  if ! /usr/bin/pgrep -q oahd; then
    info "Installing Rosetta 2..."
    softwareupdate --install-rosetta --agree-to-license
    success "Rosetta 2 installed."
  else
    success "Rosetta 2 already installed."
  fi
fi

# ── 3. Homebrew ───────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
  success "Homebrew already installed."
else
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  success "Homebrew installed."
fi

eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"
info "Updating Homebrew..."
brew update --quiet

# ── 4. Clone macos-config (with dotfiles submodule) ──────────────────────────
if [[ -d "${MACOS_CONFIG_DIR}/.git" ]]; then
  success "macos-config already cloned at ${MACOS_CONFIG_DIR}."
  info "Pulling latest changes..."
  git -C "${MACOS_CONFIG_DIR}" pull --recurse-submodules
else
  info "Cloning macos-config..."
  git clone --recurse-submodules "${MACOS_CONFIG_REPO}" "${MACOS_CONFIG_DIR}"
  success "macos-config cloned to ${MACOS_CONFIG_DIR}."
fi

# ── 5. Choose machine profile ─────────────────────────────────────────────────
echo ""
ask "Machine profile — enter 'work' or 'personal':"
read -r PROFILE
while [[ "${PROFILE}" != "work" && "${PROFILE}" != "personal" ]]; do
  ask "Please enter exactly 'work' or 'personal':"
  read -r PROFILE
done
success "Profile: ${PROFILE}"

# ── 6. Install Homebrew packages ──────────────────────────────────────────────
info "Installing common packages (this may take 20–40 minutes)..."
brew bundle --no-lock --file="${MACOS_CONFIG_DIR}/Brewfile.common"
success "Common packages installed."

info "Installing ${PROFILE}-specific packages..."
brew bundle --no-lock --file="${MACOS_CONFIG_DIR}/Brewfile.${PROFILE}"
success "${PROFILE} packages installed."

# ── 7. 1Password CLI sign-in ──────────────────────────────────────────────────
echo ""
info "Checking 1Password CLI sign-in..."
if ! op account list &>/dev/null 2>&1; then
  echo ""
  warn "You need to sign into 1Password CLI so chezmoi can apply secrets."
  echo "  Run: eval \"\$(op signin)\""
  echo ""
  ask "Press Enter once signed in (or Ctrl-C to skip — secrets won't be applied now)..."
  read -r
fi

if op account list &>/dev/null 2>&1; then
  success "1Password CLI is signed in."
else
  warn "Skipping 1Password. Run 'eval \"\$(op signin)\"' then 'chezmoi apply' later."
fi

# ── 8. chezmoi: apply dotfiles ───────────────────────────────────────────────
info "Initialising chezmoi from ${DOTFILES_REPO} ..."
echo "You will be prompted for your machine type, full name, and email."
echo ""
chezmoi init --apply "${DOTFILES_REPO}"
success "Dotfiles applied."

# ── 9. macOS system defaults ──────────────────────────────────────────────────
info "Applying macOS system defaults..."
bash "${MACOS_CONFIG_DIR}/scripts/apply-defaults.sh"

# ── done ──────────────────────────────────────────────────────────────────────
echo ""
success "Bootstrap complete!"
echo ""
echo "  Remaining manual steps:"
echo "  1. Restart your terminal (or open a new shell session)."
echo "  2. Sign into the Mac App Store if not done, then re-run:"
echo "       brew bundle --no-lock --file=${MACOS_CONFIG_DIR}/Brewfile.common"
echo "       brew bundle --no-lock --file=${MACOS_CONFIG_DIR}/Brewfile.${PROFILE}"
echo "  3. Open 1Password → Settings → Developer → enable SSH agent integration."
echo "  4. Configure 1Password secrets in your dotfiles — see:"
echo "       https://github.com/praivio/macos-dotfiles#secrets"
echo "  5. A full restart is recommended for macOS defaults to take full effect."
echo ""
