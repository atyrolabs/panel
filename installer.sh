#!/usr/bin/env bash
# Atyro Panel installer — dependency-aware, repeatable Debian/Ubuntu installer
# Usage: bash install.sh [installation-directory]

set -Eeuo pipefail
IFS=$'\n\t'

REPO_URL="https://github.com/atyrolabs/panel.git"
ZIP_NAME="atyro-panel-v1.0.0.zip"
DEFAULT_DIR="/var/www/panel"
NODE_MAJOR="24"

ORANGE='\033[38;5;208m'; WHITE='\033[1;37m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; DIM='\033[2m'
BOLD='\033[1m'; RESET='\033[0m'
if [[ ! -t 1 ]]; then
  ORANGE=''; WHITE=''; GREEN=''; YELLOW=''; RED=''; DIM=''; BOLD=''; RESET=''
fi

WORK_DIR=""
SUDO=()

step() { printf "\n%b➜%b %b%s%b\n" "$ORANGE$BOLD" "$RESET" "$WHITE" "$1" "$RESET"; }
ok()   { printf "%b✔%b %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "%b⚠%b %s\n" "$YELLOW" "$RESET" "$1"; }
fail() { printf "%b✖%b %s\n" "$RED" "$RESET" "$1" >&2; }

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}
on_error() {
  local code=$?
  trap - ERR
  fail "Installation failed (exit code $code, near line ${BASH_LINENO[0]:-unknown})."
  if [[ -n "$WORK_DIR" && -f "$WORK_DIR/npm.log" ]]; then
    printf "\n%s\n" "Last npm output:"
    tail -n 60 "$WORK_DIR/npm.log" >&2 || true
  fi
  exit "$code"
}
trap on_error ERR
trap cleanup EXIT

prompt_value() {
  local prompt="$1" default="$2" answer=""
  if [[ -r /dev/tty ]]; then
    printf "%b%s%b %b[default: %s]%b: " "$WHITE" "$prompt" "$RESET" "$DIM" "$default" "$RESET" >/dev/tty
    IFS= read -r answer </dev/tty || true
  else
    printf "%s (default: %s)\n" "$prompt" "$default"
  fi
  printf '%s' "${answer:-$default}"
}

has_tty() { [[ -r /dev/tty && -w /dev/tty ]]; }

printf "%b" "$ORANGE$BOLD"
cat <<'BANNER'
   _____               _   _   ______   _
  |  __ \      /\     | \ | | |  ____| | |
  | |__) |    /  \    |  \| | | |__    | |
  |  ___/    / /\ \   | . ` | |  __|   | |
  | |       / ____ \  | |\  | | |____  | |____
  |_|      /_/    \_\ |_| \_| |______| |______|
BANNER
printf "%b" "$RESET"
printf "%b             ATYRO PANEL INSTALLER%b\n" "$WHITE$BOLD" "$RESET"
printf "%b       Automatic dependency installation%b\n\n" "$DIM" "$RESET"

if [[ "$EUID" -eq 0 ]]; then
  SUDO=()
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  SUDO=(sudo)
elif has_tty && command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  fail "Run as root, or provide sudo access. Example: sudo bash install.sh"
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  fail "Cannot identify this operating system. Debian/Ubuntu is required."
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
OS_ID="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"
if [[ "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" && "$OS_LIKE" != *debian* ]]; then
  fail "This installer currently supports Debian/Ubuntu-based systems only (detected: $OS_ID)."
  exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
  fail "apt-get is required on this operating system."
  exit 1
fi

step "Checking and installing system dependencies"
APT_PACKAGES=(git unzip curl ca-certificates gnupg build-essential python3 make g++)
"${SUDO[@]}" apt-get update -y
"${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}"
ok "System dependencies are installed."

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1 ||
   (( $(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0) < NODE_MAJOR )); then
  step "Installing Node.js ${NODE_MAJOR}.x LTS and npm"
  NODE_SETUP="$(mktemp -t atyro-nodesource.XXXXXX)"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" -o "$NODE_SETUP"
  "${SUDO[@]}" bash "$NODE_SETUP"
  rm -f "$NODE_SETUP"
  "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

for cmd in git unzip curl node npm; do
  command -v "$cmd" >/dev/null 2>&1 || { fail "Required command '$cmd' is still unavailable after installation."; exit 1; }
done
NODE_VERSION="$(node --version)"
NODE_MAJOR_INSTALLED="$(node -p 'Number(process.versions.node.split(".")[0])')"
if (( NODE_MAJOR_INSTALLED < NODE_MAJOR )); then
  fail "Node.js ${NODE_MAJOR}.x or newer is required; found $NODE_VERSION."
  exit 1
fi
ok "Node.js $NODE_VERSION and npm $(npm --version) are ready."

INSTALL_DIR="${1:-}"
if [[ -z "$INSTALL_DIR" ]]; then
  INSTALL_DIR="$(prompt_value "Installation directory" "$DEFAULT_DIR")"
fi
INSTALL_DIR="${INSTALL_DIR%/}"
[[ -n "$INSTALL_DIR" && "$INSTALL_DIR" != "/" ]] || { fail "Invalid installation directory."; exit 1; }
if [[ -e "$INSTALL_DIR" && ! -d "$INSTALL_DIR" ]]; then
  fail "The installation path exists but is not a directory: $INSTALL_DIR"
  exit 1
fi
if [[ -d "$INSTALL_DIR" ]] && find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  warn "The target directory is not empty. Existing files may be updated; your .env will be preserved."
  if has_tty; then
    printf "Continue? [y/N]: " >/dev/tty
    IFS= read -r answer </dev/tty || answer=""
    [[ "$answer" =~ ^[Yy]$ ]] || { printf "Cancelled.\n"; exit 0; }
  else
    fail "Non-empty target directory requires interactive confirmation. Re-run with a clean directory."
    exit 1
  fi
fi

WORK_DIR="$(mktemp -d -t atyro-panel-install.XXXXXX)"
# Back up user configuration before copying release files over the target.
[[ ! -f "$INSTALL_DIR/.env" ]] || cp -p "$INSTALL_DIR/.env" "$WORK_DIR/existing.env"
[[ ! -f "$INSTALL_DIR/test.env" ]] || cp -p "$INSTALL_DIR/test.env" "$WORK_DIR/existing.test.env"

step "Downloading Atyro Panel source"
if ! git clone --depth 1 "$REPO_URL" "$WORK_DIR/repository" >"$WORK_DIR/git.log" 2>&1; then
  cat "$WORK_DIR/git.log" >&2
  fail "Could not clone the repository. Check network access and GitHub availability."
  exit 1
fi
ok "Repository downloaded."

ZIP_PATH="$WORK_DIR/repository/$ZIP_NAME"
if [[ ! -f "$ZIP_PATH" ]]; then
  fail "Archive not found in repository: $ZIP_NAME"
  printf "Confirm that the release archive exists at the repository root.\n" >&2
  exit 1
fi

step "Extracting release archive"
mkdir -p "$WORK_DIR/extracted"
unzip -q "$ZIP_PATH" -d "$WORK_DIR/extracted"
SOURCE_DIR="$WORK_DIR/extracted"
if [[ ! -f "$SOURCE_DIR/package.json" ]]; then
  PACKAGE_JSON="$(find "$WORK_DIR/extracted" -mindepth 2 -maxdepth 5 -type f -name package.json -print -quit)"
  if [[ -n "$PACKAGE_JSON" ]]; then
    SOURCE_DIR="$(dirname "$PACKAGE_JSON")"
  fi
fi
if [[ ! -f "$SOURCE_DIR/package.json" ]]; then
  fail "package.json was not found in the release archive."
  exit 1
fi
node -e "const p=require(process.argv[1]); if(!p.name) process.exit(1)" "$SOURCE_DIR/package.json" || {
  fail "package.json is invalid or missing its package name."
  exit 1
}
mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
cp -a "$SOURCE_DIR/." "$INSTALL_DIR/"
[[ ! -f "$WORK_DIR/existing.env" ]] || cp -p "$WORK_DIR/existing.env" "$INSTALL_DIR/.env"
[[ ! -f "$WORK_DIR/existing.test.env" ]] || cp -p "$WORK_DIR/existing.test.env" "$INSTALL_DIR/test.env"
ok "Panel files copied to $INSTALL_DIR; existing environment files preserved."

step "Configuring environment"
ENV_FILE="$INSTALL_DIR/.env"
if [[ ! -f "$ENV_FILE" && -f "$INSTALL_DIR/test.env" ]]; then
  cp -p "$INSTALL_DIR/test.env" "$ENV_FILE"
fi
if [[ ! -f "$ENV_FILE" ]]; then
  PORT="$(prompt_value "PORT" "3000")"
  HOST="$(prompt_value "HOST" "0.0.0.0")"
  NODE_ENV="$(prompt_value "NODE_ENV" "production")"
  SESSION_SECRET="$(node -e "process.stdout.write(require('crypto').randomBytes(48).toString('hex'))")"
  umask 077
  cat >"$ENV_FILE" <<EOF
PORT=$PORT
HOST=$HOST
NODE_ENV=$NODE_ENV
SESSION_SECRET=$SESSION_SECRET
EOF
  chmod 600 "$ENV_FILE"
else
  warn "Existing .env found; preserving it and all existing settings."
  grep -q '^PORT=' "$ENV_FILE" || printf '\nPORT=3000\n' >>"$ENV_FILE"
  grep -q '^HOST=' "$ENV_FILE" || printf 'HOST=0.0.0.0\n' >>"$ENV_FILE"
  grep -q '^NODE_ENV=' "$ENV_FILE" || printf 'NODE_ENV=production\n' >>"$ENV_FILE"
  if ! grep -q '^SESSION_SECRET=' "$ENV_FILE" ||
     grep -q '^SESSION_SECRET=$' "$ENV_FILE" ||
     grep -q '^SESSION_SECRET=change-this-to-a-random-secret-key$' "$ENV_FILE"; then
    SECRET="$(node -e "process.stdout.write(require('crypto').randomBytes(48).toString('hex'))")"
    if grep -q '^SESSION_SECRET=' "$ENV_FILE"; then
      sed -i "s|^SESSION_SECRET=.*|SESSION_SECRET=$SECRET|" "$ENV_FILE"
    else
      printf '\nSESSION_SECRET=%s\n' "$SECRET" >>"$ENV_FILE"
    fi
  fi
  chmod 600 "$ENV_FILE"
fi
# Maintain compatibility without replacing an existing compatibility file.
if [[ ! -f "$INSTALL_DIR/test.env" ]]; then
  cp "$ENV_FILE" "$INSTALL_DIR/test.env"
  chmod 600 "$INSTALL_DIR/test.env"
fi
ok "Environment configuration is ready (secrets are not displayed)."

step "Installing and validating npm dependencies"
cd "$INSTALL_DIR"
if [[ -f package-lock.json ]]; then
  if ! npm ci --no-audit --no-fund >"$WORK_DIR/npm.log" 2>&1; then
    warn "npm ci failed (lockfile may be out of sync); trying npm install."
    if ! npm install --no-audit --no-fund >>"$WORK_DIR/npm.log" 2>&1; then
      tail -n 80 "$WORK_DIR/npm.log" >&2
      fail "Could not install npm dependencies."
      exit 1
    fi
  fi
else
  if ! npm install --no-audit --no-fund >"$WORK_DIR/npm.log" 2>&1; then
    tail -n 80 "$WORK_DIR/npm.log" >&2
    fail "Could not install npm dependencies."
    exit 1
  fi
fi
npm ls --depth=0 >/dev/null 2>&1 || warn "npm reports optional/peer dependency warnings; review 'npm ls --depth=0'."
ok "npm dependencies installed."

# Keep permissions private for environment files.
chmod 600 "$ENV_FILE" "$INSTALL_DIR/test.env" 2>/dev/null || true

printf "\n%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$GREEN$BOLD" "$RESET"
printf "%b  ✔ ATYRO PANEL INSTALLATION COMPLETE%b\n" "$GREEN$BOLD" "$RESET"
printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$GREEN$BOLD" "$RESET"
printf "%bInstall path:%b %s\n" "$WHITE" "$RESET" "$INSTALL_DIR"
printf "%bConfig file:%b  %s\n" "$WHITE" "$RESET" "$ENV_FILE"
printf "%bNode.js:%b      %s\n" "$WHITE" "$RESET" "$NODE_VERSION"
printf "%bEnvironment:%b  %s\n\n" "$WHITE" "$RESET" "$(grep '^NODE_ENV=' "$ENV_FILE" | tail -n1 | cut -d= -f2-)"
printf "%bNext steps%b\n" "$ORANGE$BOLD" "$RESET"
printf "  1. cd %q\n" "$INSTALL_DIR"
printf "  2. Review README/package.json for the supported start command.\n"
printf "  3. Start the panel using the project's documented command.\n"
printf "  4. For production, use a process manager and configure your reverse proxy.\n\n"
printf "%bNote:%b The installer does not guess or automatically launch an application service.\n" "$DIM" "$RESET"
