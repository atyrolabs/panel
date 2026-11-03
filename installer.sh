#!/usr/bin/env bash
# Atyro Panel v1.0.0 installer
# Usage: bash install.sh [installation-directory]

set -Eeuo pipefail

REPO_URL="https://github.com/atyrolabs/panel.git"
ZIP_NAME="atyro-panel-v1.0.0.zip"
DEFAULT_DIR="/var/www/panel"

# Orange-themed terminal UI
ORANGE='\033[38;5;208m'
WHITE='\033[1;37m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

if [[ ! -t 1 ]]; then
  ORANGE='' WHITE='' GREEN='' YELLOW='' RED='' DIM='' BOLD='' RESET=''
fi

spin() {
  local pid="$1" message="$2"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r${ORANGE}%s${RESET} %s" "${frames[i % ${#frames[@]}]}" "$message"
    i=$((i + 1))
    sleep 0.1
  done
  wait "$pid"
  local result=$?
  printf "\r"
  return "$result"
}

step() { printf "\n${ORANGE}${BOLD}➜${RESET} ${WHITE}%s${RESET}\n" "$1"; }
ok()   { printf "${GREEN}✔${RESET} %s\n" "$1"; }
warn() { printf "${YELLOW}⚠${RESET} %s\n" "$1"; }
fail() { printf "${RED}✖${RESET} %s\n" "$1" >&2; }

cleanup() {
  [[ -n "${WORK_DIR:-}" && -d "${WORK_DIR:-}" ]] && rm -rf -- "$WORK_DIR"
}
on_error() {
  local code=$?
  fail "Installation failed near line ${BASH_LINENO[0]:-unknown} (exit code: $code)."
  [[ -n "${WORK_DIR:-}" ]] && printf "${DIM}Temporary files: %s${RESET}\n" "$WORK_DIR"
  exit "$code"
}
trap on_error ERR

clear 2>/dev/null || true
printf "${ORANGE}${BOLD}"
cat <<'BANNER'
    _    _______ __   __ ____   ___
   / \  |_   _\ \ / /  / ___| / _ \
  / _ \   | |  \ V /  | |    | | | |
 / ___ \  | |   | |   | |___ | |_| |
/_/   \_\ |_|   |_|    \____| \___/
BANNER
printf "${RESET}"
printf "${WHITE}${BOLD}             ATYRO PANEL v1.0.0${RESET}\n"
printf "${DIM}          Interactive Installation Wizard${RESET}\n\n"

if [[ "${EUID}" -ne 0 ]]; then
  warn "Not running as root. You may need sudo permissions for /var/www."
fi

# Install Node.js + npm automatically when missing (interactive yes/no).
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  printf "\n${YELLOW}Node.js and/or npm are not installed.${RESET}\n"
  printf "Install Node.js 23.x and npm automatically using NodeSource? [Y/n]: "
  read -r install_node
  install_node="${install_node:-Y}"

  if [[ "$install_node" =~ ^[Yy]$ ]]; then
    if ! command -v apt-get >/dev/null 2>&1; then
      fail "Automatic Node.js installation currently supports Debian/Ubuntu (apt-get)."
      exit 1
    fi

    if [[ "${EUID}" -ne 0 ]]; then
      if ! command -v sudo >/dev/null 2>&1; then
        fail "Please run this installer as root (sudo is unavailable)."
        exit 1
      fi
      SUDO="sudo"
    else
      SUDO=""
    fi

    if ! command -v curl >/dev/null 2>&1; then
      step "Installing curl prerequisite"
      $SUDO apt-get update -y
      $SUDO apt-get install -y curl
    fi

    step "Installing Node.js 23.x and npm"
    $SUDO bash -c 'curl -sL https://deb.nodesource.com/setup_23.x | bash -'
    $SUDO apt-get install -y nodejs
    ok "Node.js and npm installed."
  else
    fail "Node.js and npm are required. Install them and rerun this script."
    exit 1
  fi
fi

for cmd in git unzip node npm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Required command '$cmd' was not found. Please install it and rerun."
    exit 1
  fi
done
ok "Git, unzip, Node.js and npm are available."
printf "    Node.js: %s | npm: %s\n" "$(node --version)" "$(npm --version)"

INSTALL_DIR="${1:-}"
if [[ -z "$INSTALL_DIR" ]]; then
  printf "\n${WHITE}Installation directory${RESET} ${DIM}[default: ${DEFAULT_DIR}]${RESET}: "
  read -r INSTALL_DIR
  INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_DIR}"
fi

# Normalize trailing slash and reject dangerous destinations.
INSTALL_DIR="${INSTALL_DIR%/}"
[[ -n "$INSTALL_DIR" ]] || { fail "Installation directory cannot be /."; exit 1; }
[[ "$INSTALL_DIR" != "/" ]] || { fail "Refusing to install directly into /."; exit 1; }

if [[ -e "$INSTALL_DIR" ]] && [[ -n "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  printf "${YELLOW}The target directory already exists and is not empty:${RESET} %s\n" "$INSTALL_DIR"
  printf "Continue and allow files to be merged/overwritten? [y/N]: "
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] || { printf "Cancelled.\n"; exit 0; }
fi

WORK_DIR="$(mktemp -d -t atyro-panel-install.XXXXXX)"
trap cleanup EXIT

step "Preparing installation directory"
mkdir -p -- "$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
ok "Target: $INSTALL_DIR"

step "Cloning Atyro Labs repository"
git clone --depth 1 "$REPO_URL" "$WORK_DIR/repository" >"$WORK_DIR/git.log" 2>&1 &
pid=$!
if spin "$pid" "Cloning repository..."; then
  ok "Repository cloned."
else
  cat "$WORK_DIR/git.log" >&2
  fail "Could not clone $REPO_URL"
  exit 1
fi

ZIP_PATH="$WORK_DIR/repository/$ZIP_NAME"
if [[ ! -f "$ZIP_PATH" ]]; then
  fail "Expected archive was not found: $ZIP_NAME"
  printf "Check that the archive exists in the repository's main branch.\n"
  exit 1
fi

step "Extracting Atyro Panel v1.0.0"
mkdir -p "$WORK_DIR/extracted"
unzip -q "$ZIP_PATH" -d "$WORK_DIR/extracted" &
pid=$!
if spin "$pid" "Extracting panel files..."; then
  ok "ZIP archive extracted."
else
  fail "Could not extract $ZIP_NAME"
  exit 1
fi

# If the ZIP contains a single wrapper directory, install its contents.
SOURCE_DIR="$WORK_DIR/extracted"
if [[ ! -f "$SOURCE_DIR/package.json" ]]; then
  PACKAGE_JSON="$(find "$WORK_DIR/extracted" -mindepth 2 -maxdepth 3 -type f -name package.json -print -quit)"
  if [[ -n "$PACKAGE_JSON" ]]; then
    SOURCE_DIR="$(dirname "$PACKAGE_JSON")"
  fi
fi

if [[ ! -f "$SOURCE_DIR/package.json" ]]; then
  fail "package.json was not found in the extracted archive. Check the ZIP structure."
  exit 1
fi

cp -a "$SOURCE_DIR/." "$INSTALL_DIR/"
ok "Panel files copied into the installation directory."

step "Configuring .env"
ENV_FILE="$INSTALL_DIR/.env"
if [[ -f "$ENV_FILE" || -f "$INSTALL_DIR/test.env" ]]; then
  SOURCE_ENV="$ENV_FILE"
  [[ -f "$SOURCE_ENV" ]] || SOURCE_ENV="$INSTALL_DIR/test.env"
  warn "Existing environment file found; its current values will be used as defaults."
  old_port="$(grep -E '^PORT=' "$SOURCE_ENV" | tail -n1 | cut -d= -f2- || true)"
  old_host="$(grep -E '^HOST=' "$SOURCE_ENV" | tail -n1 | cut -d= -f2- || true)"
  old_env="$(grep -E '^NODE_ENV=' "$SOURCE_ENV" | tail -n1 | cut -d= -f2- || true)"
  old_secret="$(grep -E '^SESSION_SECRET=' "$SOURCE_ENV" | tail -n1 | cut -d= -f2- || true)"
else
  old_port="3000"
  old_host="0.0.0.0"
  old_env="development"
  old_secret=""
fi

read_value() {
  local label="$1" default="$2" result
  printf "${WHITE}%s${RESET} ${DIM}[default: %s]${RESET}: " "$label" "$default"
  read -r result
  printf '%s' "${result:-$default}"
}

PORT="$(read_value 'PORT' "${old_port:-3000}")"
HOST="$(read_value 'HOST' "${old_host:-0.0.0.0}")"
NODE_ENV="$(read_value 'NODE_ENV' "${old_env:-development}")"

if [[ -n "${old_secret:-}" && "$old_secret" != "change-this-to-a-random-secret-key" ]]; then
  default_secret="$old_secret"
else
  default_secret="$(node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex'))")"
fi
printf "${WHITE}SESSION_SECRET${RESET} ${DIM}[Enter to generate/use secure default; leave blank to accept]${RESET}: "
read -r SESSION_SECRET
SESSION_SECRET="${SESSION_SECRET:-$default_secret}"

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  fail "PORT must be a number from 1 to 65535."
  exit 1
fi
[[ -n "$HOST" ]] || { fail "HOST cannot be empty."; exit 1; }
case "$NODE_ENV" in
  development|production|test) ;;
  *) warn "NODE_ENV '$NODE_ENV' is non-standard; keeping the value you entered." ;;
esac
[[ -n "$SESSION_SECRET" ]] || { fail "SESSION_SECRET cannot be empty."; exit 1; }

umask 077
cat > "$ENV_FILE" <<EOF
# Atyro Panel v1.0.0 configuration
PORT=$PORT
HOST=$HOST
NODE_ENV=$NODE_ENV
SESSION_SECRET=$SESSION_SECRET
EOF
chmod 600 "$ENV_FILE"

# Keep test.env in sync for projects/releases that still expect that filename.
cp "$ENV_FILE" "$INSTALL_DIR/test.env"
chmod 600 "$INSTALL_DIR/test.env"
ok ".env created; test.env compatibility copy also updated (permissions 600)."

step "Installing Node.js dependencies"
cd "$INSTALL_DIR"
if [[ -f package-lock.json ]]; then
  npm ci --no-audit --no-fund >"$WORK_DIR/npm.log" 2>&1 &
else
  npm install --no-audit --no-fund >"$WORK_DIR/npm.log" 2>&1 &
fi
pid=$!
if spin "$pid" "Installing npm packages (this may take a few minutes)..."; then
  ok "Node.js dependencies installed."
else
  cat "$WORK_DIR/npm.log" >&2
  fail "npm dependency installation failed. See output above."
  exit 1
fi

printf "\n${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${GREEN}${BOLD}  ✔ ATYRO PANEL v1.0.0 INSTALLATION COMPLETE${RESET}\n"
printf "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${WHITE}Install path:${RESET} %s\n" "$INSTALL_DIR"
printf "${WHITE}Config file: ${RESET} %s\n" "$ENV_FILE"
printf "${WHITE}Compatibility:${RESET} %s/test.env\n" "$INSTALL_DIR"
printf "${WHITE}Listen address:${RESET} %s:%s\n" "$HOST" "$PORT"
printf "${WHITE}Environment:  ${RESET} %s\n" "$NODE_ENV"
printf "${YELLOW}Session secret:${RESET} saved privately in test.env (not displayed)\n\n"

printf "${ORANGE}${BOLD}Next steps${RESET}\n"
printf "  1. cd %q\n" "$INSTALL_DIR"
printf "  2. Check the project's README/package.json for the correct start command.\n"
printf "  3. Ensure the app loads ${BOLD}test.env${RESET}; Node.js apps do not automatically load that filename by default.\n"
printf "  4. For production, set NODE_ENV=production and use a process manager/reverse proxy.\n\n"
printf "${DIM}The installer does not start a service because the project's supported start command has not been assumed.${RESET}\n"
