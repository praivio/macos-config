#!/bin/bash
# =============================================================================
# bootstrap.sh — macOS setup entry point
#
# Usage (fresh machine):
#   curl -fsSL https://raw.githubusercontent.com/praivio/macos-config/main/bootstrap.sh | bash
#
# Or clone first and run locally:
#   bash bootstrap.sh
# =============================================================================
set -euo pipefail

CHEZMOI_REPO="git@github.com:praivio/macos-config.git"
HOMEBREW_PREFIX="/opt/homebrew"   # Apple Silicon default; adjusted below for Intel

# ── helpers ──────────────────────────────────────────────────────────────────
info()    { printf "\033[0;34m▶ %s\033[0m\n" "$*"; }
success() { printf "\033[0;32m✔ %s\033[0m\n" "$*"; }
warn()    { printf "\033[0;33m⚠ %s\033[0m\n" "$*"; }
die()     { printf "\033[0;31m✖ %s\033[0m\n" "$*" >&2; exit 1; }

# ── architecture detection ────────────────────────────────────────────────────
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
  warn "Intel Mac detected. Homebrew path set to /usr/local."
fi

# ── 1. macOS software updates ─────────────────────────────────────────────────
info "Checking for macOS software updates..."
sudo softwareupdate --install --all --agree-to-license 2>/dev/null || warn "Software update skipped (may require manual run)."

# ── 2. Xcode Command Line Tools ───────────────────────────────────────────────
if xcode-select -p &>/dev/null; then
  success "Xcode Command Line Tools already installed."
else
  info "Installing Xcode Command Line Tools..."
  # Trigger the GUI installer via a known trick that avoids the full Xcode download
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  softwareupdate --install "$(softwareupdate --list 2>/dev/null \
    | grep -E 'Command Line Tools for Xcode' \
    | sort -V \
    | tail -1 \
    | sed 's/^[[:space:]]*\* //')" --agree-to-license
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  success "Xcode Command Line Tools installed."
fi

# ── 3. Homebrew ───────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
  success "Homebrew already installed."
else
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"
  success "Homebrew installed."
fi

# Ensure brew is on PATH for this session
eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"

info "Updating Homebrew..."
brew update --quiet

# ── 4. chezmoi ───────────────────────────────────────────────────────────────
if command -v chezmoi &>/dev/null; then
  success "chezmoi already installed."
else
  info "Installing chezmoi..."
  brew install chezmoi
  success "chezmoi installed."
fi

# ── 5. chezmoi init + apply ───────────────────────────────────────────────────
info "Initialising chezmoi from ${CHEZMOI_REPO} ..."
info "You will be prompted for your machine type and any template variables."
echo ""

# --apply runs all scripts (including brew bundle) immediately after init
chezmoi init --apply "${CHEZMOI_REPO}"

echo ""
success "Bootstrap complete!"
echo ""
echo "  Next steps:"
echo "  1. Sign into the Mac App Store, then run:"
echo "     chezmoi apply   (to install App Store apps via mas)"
echo "  2. Restart your terminal (or open a new shell session)."
echo "  3. Review ~/README-post-install.md for any remaining manual steps."
echo ""
