#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_header() { echo -e "${BLUE}$*${NC}"; }
log_info() { echo -e "${BLUE}INFO${NC} $*"; }
log_warn() { echo -e "${YELLOW}WARN${NC} $*"; }
log_ok() { echo -e "${GREEN}OK${NC}   $*"; }
log_err() { echo -e "${RED}ERR${NC}  $*" >&2; }

on_cancel() {
  log_warn "Cancelled. You can re-run this script safely."
  exit 130
}

trap on_cancel INT TERM

have() { command -v "$1" >/dev/null 2>&1; }

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

is_true() {
  case "$(lower "${1:-}")" in
    true|1|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}

tty_present() { [ -t 0 ] && [ -t 1 ]; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    return 1
  fi
}

setup_brew_shellenv() {
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi
  if [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi
  if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    return 0
  fi
  return 1
}

ensure_path_basics() {
  if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

ensure_chezmoi() {
  ensure_path_basics

  if have chezmoi; then
    log_ok "chezmoi already installed"
    return 0
  fi

  if ! have curl; then
    log_err "curl is required to install chezmoi"
    return 1
  fi

  log_info "Installing chezmoi (get.chezmoi.io)"
  sh -c "$(curl -fsLS get.chezmoi.io)"

  ensure_path_basics

  if have chezmoi; then
    log_ok "chezmoi installed"
    return 0
  fi

  log_err "chezmoi installation completed but chezmoi is not in PATH"
  log_err "Expected at: $HOME/.local/bin/chezmoi"
  return 1
}

install_gh_with_brew() {
  if ! have brew; then
    return 1
  fi

  log_info "Installing gh via brew"
  brew install gh
}

install_gh_with_apt() {
  if ! have apt-get; then
    return 1
  fi
  log_info "Installing gh via apt-get"
  as_root apt-get update
  as_root apt-get install -y gh
}

install_gh_with_dnf() {
  if ! have dnf; then
    return 1
  fi
  log_info "Installing gh via dnf"
  as_root dnf install -y gh
}

install_gh_with_pacman() {
  if ! have pacman; then
    return 1
  fi
  log_info "Installing gh via pacman"
  as_root pacman -S --noconfirm github-cli
}

ensure_gh() {
  if have gh; then
    log_ok "gh already installed"
    return 0
  fi

  setup_brew_shellenv >/dev/null 2>&1 || true

  if install_gh_with_brew; then
    log_ok "gh installed"
    return 0
  fi

  case "$(uname -s)" in
    Darwin)
      log_err "gh is required but Homebrew is not available"
      log_err "Install gh manually or install Homebrew: https://brew.sh"
      return 1
      ;;
    Linux)
      if install_gh_with_apt || install_gh_with_dnf || install_gh_with_pacman; then
        log_ok "gh installed"
        return 0
      fi
      log_err "No supported package manager found to install gh (brew/apt-get/dnf/pacman)"
      log_err "Please install GitHub CLI manually: https://cli.github.com"
      return 1
      ;;
    *)
      log_err "Unsupported OS for this bootstrap script: $(uname -s)"
      return 1
      ;;
  esac
}

gh_is_authenticated() {
  gh auth status --hostname "$DOTFILES_GITHUB_HOST" >/dev/null 2>&1
}

ensure_gh_auth() {
  if gh_is_authenticated; then
    log_ok "gh authenticated for $DOTFILES_GITHUB_HOST"
    return 0
  fi

  if [ -n "${GH_TOKEN:-}" ]; then
    log_warn "GH_TOKEN is set but gh has no stored auth; continuing without interactive login"
    return 0
  fi

  local non_interactive=false
  if ! tty_present; then
    non_interactive=true
  fi
  if is_true "${CI:-false}" || [ "${DEBIAN_FRONTEND:-}" = "noninteractive" ]; then
    non_interactive=true
  fi

  if [ "$non_interactive" = true ]; then
    log_err "Non-interactive mode detected but no GH_TOKEN provided."
    log_err "Run this script in a TTY to complete 'gh auth login', or set GH_TOKEN."
    return 1
  fi

  log_info "Authenticating with GitHub ($DOTFILES_GITHUB_HOST)"

  if [ "${BROWSER:-}" = "false" ] || [ "${GH_BROWSER:-}" = "none" ]; then
    log_info "Headless mode detected (BROWSER=false or GH_BROWSER=none); using device-code flow"
    log_info "Follow the prompts from gh: open the URL it prints and enter the one-time code."
    BROWSER=false gh auth login --web --hostname "$DOTFILES_GITHUB_HOST" --git-protocol https -s repo
  else
    gh auth login --web --hostname "$DOTFILES_GITHUB_HOST" --git-protocol https -s repo
  fi

  if gh_is_authenticated; then
    log_ok "gh authenticated"
    return 0
  fi

  log_err "Authentication failed or was cancelled. Bootstrap cannot proceed without GitHub access."
  return 1
}

maybe_setup_git() {
  if is_true "${DOTFILES_NO_GH_SETUP_GIT:-false}"; then
    log_warn "Skipping 'gh auth setup-git' (DOTFILES_NO_GH_SETUP_GIT=true)"
    return 0
  fi

  log_info "Configuring git to use gh for HTTPS auth"
  gh auth setup-git --hostname "$DOTFILES_GITHUB_HOST"
  log_ok "gh auth setup-git complete"
}

run_chezmoi() {
  ensure_path_basics

  log_info "Applying dotfiles with chezmoi"

  local source_dir=""
  source_dir="$(chezmoi source-path 2>/dev/null || true)"
  if [ -z "$source_dir" ]; then
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    source_dir="$data_home/chezmoi"
  fi

  if [ -d "$source_dir/.git" ]; then
    chezmoi apply
  else
    local override_data='{"git":{"user_name":"","user_email":""}}'
    local err_log=""
    err_log="$(mktemp "${TMPDIR:-/tmp}/dotfiles-chezmoi-init.XXXXXX")"

    if ! chezmoi init --apply "vgaonkar" 2> >(tee "$err_log" >&2); then
      if grep -Fq 'map has no entry for key "git"' "$err_log"; then
        log_warn "chezmoi init failed due to missing git template data; retrying with minimal override-data"
        rm -f "$err_log"
        chezmoi init --apply "vgaonkar" --override-data "$override_data"
      else
        rm -f "$err_log"
        return 1
      fi
    fi

    rm -f "$err_log"
  fi

  log_ok "chezmoi apply complete"
}

main() {
  DOTFILES_GITHUB_HOST="${DOTFILES_GITHUB_HOST:-github.com}"
  DOTFILES_GIT_PROTOCOL="${DOTFILES_GIT_PROTOCOL:-https}"
  DOTFILES_NO_GH_SETUP_GIT="${DOTFILES_NO_GH_SETUP_GIT:-false}"

  log_header "Dotfiles Bootstrap (macOS/Linux)"
  log_info "Detected: $(uname -s) ($(uname -m))"
  log_info "GitHub host: $DOTFILES_GITHUB_HOST"

  if [ "$(lower "$DOTFILES_GIT_PROTOCOL")" != "https" ]; then
    log_warn "DOTFILES_GIT_PROTOCOL='$DOTFILES_GIT_PROTOCOL' ignored for bootstrap; forcing https"
  fi

  ensure_chezmoi
  ensure_gh
  ensure_gh_auth
  maybe_setup_git
  run_chezmoi

  log_ok "Bootstrap complete"
}

main "$@"
