#!/usr/bin/env bash
#
# setup-oc-demo.sh — provision a Mac for the opencode / OpenRouter demo.
#
#   1. creates ~/projects/oc-demo/{k3,glm,claude,inkling,deepseek}
#   2. installs opencode, or upgrades it if a newer release exists
#   3. puts opencode on PATH permanently
#   4. installs the tuned OpenRouter provider-routing config
#
# Anything missing is created without asking. Anything that already exists and
# holds data is left alone unless you confirm — prompts default to NO.
#
#   ./setup-oc-demo.sh              # ask before replacing existing data
#   ./setup-oc-demo.sh --check      # report only, change nothing
#   ./setup-oc-demo.sh --yes        # unattended: replace existing (DESTRUCTIVE)
#   ./setup-oc-demo.sh --no         # unattended: never replace, only fill gaps
#
set -euo pipefail

DEMO_ROOT="$HOME/projects/oc-demo"
DEMO_DIRS=(k3 glm claude inkling deepseek)
CONFIG_DIR="$HOME/.config/opencode"
CONFIG_FILE="$CONFIG_DIR/opencode.json"
INSTALL_DIR="$HOME/.opencode/bin"
REPO="anomalyco/opencode"

DRY_RUN=false
ASSUME=""          # "" = ask interactively | yes | no

for arg in "$@"; do
  case "$arg" in
    --check)     DRY_RUN=true ;;
    --yes|-y)    ASSUME=yes ;;
    --no)        ASSUME=no ;;
    -h|--help)   sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

B=$'\033[1m'; G=$'\033[0;32m'; Y=$'\033[0;33m'; R=$'\033[0;31m'; D=$'\033[0;2m'; N=$'\033[0m'
ok()   { echo "  ${G}✓${N} $*"; }
info() { echo "  ${D}·${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; }
err()  { echo "  ${R}✗${N} $*" >&2; }
step() { echo; echo "${B}$*${N}"; }
act()  { $DRY_RUN && { info "would: $*"; return 1; } || return 0; }

# Ask a yes/no question. Defaults to NO everywhere it is ambiguous: on --no, on
# a non-interactive shell, and on a bare Enter. Reads from /dev/tty so it still
# works when the script itself arrives on stdin (curl ... | bash).
confirm() {
  local prompt="$1" reply
  case "$ASSUME" in
    yes) warn "--yes: $prompt → YES"; return 0 ;;
    no)  info "--no: $prompt → no"  ; return 1 ;;
  esac
  if [[ ! -r /dev/tty ]]; then
    warn "non-interactive shell, assuming NO: $prompt"; return 1
  fi
  printf '  %s%s%s [y/N] ' "$Y" "$prompt" "$N" > /dev/tty
  read -r reply < /dev/tty || return 1
  [[ "$reply" == [Yy] || "$reply" == [Yy][Ee][Ss] ]]
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This script targets macOS only (found $(uname -s))."; exit 1
fi

$DRY_RUN && echo "${Y}CHECK MODE — nothing will be modified.${N}"

# ── 1. project folders ────────────────────────────────────────────────────────
step "1. Project folders"

missing=() populated=()
for d in "${DEMO_DIRS[@]}"; do
  target="$DEMO_ROOT/$d"
  if [[ ! -d "$target" ]]; then
    missing+=("$d")
  elif [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
    populated+=("$d")
  else
    info "exists (empty): ~/projects/oc-demo/$d"
  fi
done

# Missing folders are simply created — nothing to lose.
# NB: ${arr[@]+"${arr[@]}"} — bash 3.2 (stock on macOS) treats a bare
# "${arr[@]}" on an empty array as an unbound variable under `set -u`.
for d in ${missing[@]+"${missing[@]}"}; do
  if act "mkdir ~/projects/oc-demo/$d"; then
    mkdir -p "$DEMO_ROOT/$d"; ok "created: ~/projects/oc-demo/$d"
  fi
done

# Folders holding files need explicit consent before being wiped.
if (( ${#populated[@]:-0} )); then
  echo
  warn "${#populated[@]} folder(s) already contain files:"
  for d in ${populated[@]+"${populated[@]}"}; do
    n=$(find "$DEMO_ROOT/$d" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
    echo "      ~/projects/oc-demo/$d  ${D}($n item(s))${N}"
  done
  if $DRY_RUN; then
    info "would ask whether to delete their contents"
  elif confirm "Delete the contents of these ${#populated[@]} folder(s) and start clean?"; then
    for d in ${populated[@]+"${populated[@]}"}; do
      target="$DEMO_ROOT/$d"
      # Belt and braces before any rm -rf: non-empty var, correct prefix, real dir.
      if [[ -n "$target" && "$target" == "$DEMO_ROOT/"* && -d "$target" ]]; then
        rm -rf -- "$target"; mkdir -p "$target"; ok "emptied: ~/projects/oc-demo/$d"
      else
        err "refusing to delete unexpected path: $target"
      fi
    done
  else
    info "kept as-is — existing files untouched"
  fi
fi

# ── 2. opencode install / upgrade ─────────────────────────────────────────────
step "2. opencode CLI"

latest="$(curl -fsSL --max-time 20 "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
          | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1 || true)"
[[ -z "$latest" ]] && warn "could not reach GitHub for the latest version (rate limit or offline)"

if command -v opencode >/dev/null 2>&1; then
  current="$(opencode --version 2>/dev/null | head -1 | tr -d '[:space:]')"
  where="$(command -v opencode)"
  info "installed: v${current:-unknown}  ($where)"
  [[ -n "$latest" ]] && info "latest   : v$latest"

  if [[ -n "$latest" && "$current" == "$latest" ]]; then
    ok "already up to date"
  elif [[ -n "$latest" ]]; then
    # Homebrew installs must be upgraded through brew, or the two copies diverge.
    if [[ "$where" == *"/Cellar/"* ]] || { command -v brew >/dev/null 2>&1 && brew list --formula 2>/dev/null | grep -qx opencode; }; then
      if act "brew upgrade opencode"; then
        brew upgrade opencode && ok "upgraded via Homebrew" || warn "brew upgrade failed — run it manually"
      fi
    elif act "opencode upgrade"; then
      opencode upgrade && ok "upgraded to v$latest" \
        || { warn "self-upgrade failed, falling back to installer"
             curl -fsSL https://opencode.ai/install | bash && ok "reinstalled via installer"; }
    fi
  fi
else
  warn "opencode not found"
  if act "install opencode via https://opencode.ai/install"; then
    curl -fsSL https://opencode.ai/install | bash
    ok "installed to $INSTALL_DIR"
  fi
fi

# ── 3. PATH ───────────────────────────────────────────────────────────────────
step "3. PATH"
# The official installer already appends to the right rc file. This only fills
# the gap when opencode lives in ~/.opencode/bin but the rc file never got the line.
case "$(basename "${SHELL:-/bin/zsh}")" in
  zsh)  rc="${ZDOTDIR:-$HOME}/.zshrc" ;;
  bash) rc="$HOME/.bash_profile" ;;
  *)    rc="$HOME/.profile" ;;
esac
if [[ -d "$INSTALL_DIR" && -x "$INSTALL_DIR/opencode" ]]; then
  if grep -qF "$INSTALL_DIR" "$rc" 2>/dev/null; then
    info "already on PATH via $(basename "$rc")"
  elif act "append PATH line to $rc"; then
    { echo ""
      echo "# opencode"
      echo "export PATH=\"$INSTALL_DIR:\$PATH\""
    } >> "$rc"
    ok "added to $(basename "$rc") — run: source $rc"
  fi
else
  info "opencode not in $INSTALL_DIR (managed by Homebrew/npm) — PATH already handled"
fi

# ── 4. opencode config ────────────────────────────────────────────────────────
step "4. OpenRouter routing config"

read -r -d '' DESIRED <<'JSON' || true
{
  "$schema": "https://opencode.ai/config.json",
  "permission": "allow",
  "provider": {
    "openrouter": {
      "models": {
        "z-ai/glm-5.3": {
          "limit": { "context": 200000, "output": 32000 },
          "options": {
            "max_tokens": 32000,
            "provider": {
              "order": ["modal", "baseten", "together"],
              "ignore": ["morph", "phala", "digitalocean"],
              "allow_fallbacks": true
            }
          }
        },
        "moonshotai/kimi-k3": {
          "limit": { "context": 200000, "output": 32000 },
          "options": {
            "max_tokens": 32000,
            "provider": {
              "order": ["modal", "baseten", "together"],
              "ignore": ["morph", "phala", "makora"],
              "allow_fallbacks": true
            }
          }
        }
      }
    }
  }
}
JSON

write_config() {
  mkdir -p "$CONFIG_DIR"
  printf '%s\n' "$DESIRED" > "$CONFIG_FILE"
  if command -v python3 >/dev/null 2>&1 && python3 -m json.tool "$CONFIG_FILE" >/dev/null 2>&1; then
    ok "written and JSON-validated"
  else
    ok "written"
  fi
}

normalise() { # compare semantically, not byte-for-byte
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin),sort_keys=True))' 2>/dev/null || cat
  else cat; fi
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  # Nothing there — just create it.
  act "write $CONFIG_FILE" && write_config
elif [[ "$(normalise <"$CONFIG_FILE")" == "$(printf '%s' "$DESIRED" | normalise)" ]]; then
  ok "config already matches — nothing to do"
else
  warn "a different opencode config already exists at:"
  echo "      $CONFIG_FILE"
  if $DRY_RUN; then
    info "would ask whether to replace it (a timestamped backup is always kept)"
  elif confirm "Replace it? A timestamped backup will be kept."; then
    backup="$CONFIG_FILE.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG_FILE" "$backup"; info "backup: $(basename "$backup")"
    write_config
  else
    info "kept existing config — demo routing is NOT applied on this machine"
  fi
fi

# ── 5. summary ────────────────────────────────────────────────────────────────
step "Summary"
echo "  folders : $DEMO_ROOT/{$(IFS=,; echo "${DEMO_DIRS[*]}")}"
echo "  opencode: $(command -v opencode >/dev/null 2>&1 && opencode --version 2>/dev/null || echo 'not on PATH in this shell yet')"
echo "  config  : $CONFIG_FILE"

if ! $DRY_RUN; then
  step "Next steps on this machine"
  echo "  1. Open a new terminal (or: source $rc)"
  echo "  2. Authenticate OpenRouter — the API key is NOT copied by this script:"
  echo "       opencode auth login          ${D}# choose OpenRouter, paste key${N}"
  echo "  3. Verify:  cd $DEMO_ROOT/k3 && opencode run -m openrouter/moonshotai/kimi-k3 'say hi'"
fi
