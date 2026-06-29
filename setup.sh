#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Colors
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; \
          echo -e "${CYAN} $1${NC}"; \
          echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ============================================================
# Config
# ============================================================
REPO="https://raw.githubusercontent.com/AlMagrhibi/nixos-config/main"
NIXOS_DIR="/etc/nixos"
TMP_DIR="/tmp/nixos-config"
BACKUP_DIR="/etc/nixos/backup-$(date +%Y%m%d-%H%M%S)"
FILES=("flake.nix" "configuration.nix" "home.nix")

# ============================================================
# STEP 1: Verify execution environment
# ============================================================
step "STEP 1 — Verifying execution environment"

# Must run as root
if [ "$EUID" -ne 0 ]; then
  error "Please run as root: sudo bash setup.sh"
fi
ok "Running as root"

# Check internet (curl instead of ping - works on networks that block ICMP)
log "Checking internet connectivity..."
if ! curl -fsSL https://github.com >/dev/null 2>&1; then
  error "No internet connection. Please connect first."
fi
ok "Internet OK"

# Check disk space (minimum 10GB free)
log "Checking disk space..."
FREE_KB=$(df / | awk 'NR==2 {print $4}')
FREE_GB=$(( FREE_KB / 1024 / 1024 ))
if [ "$FREE_KB" -lt 10485760 ]; then
  error "Not enough disk space. Have ${FREE_GB}GB free, need at least 10GB."
fi
ok "Disk space OK (${FREE_GB}GB free)"

# Check required commands
log "Checking required commands..."
for cmd in curl nix nixos-rebuild systemctl; do
  if ! command -v "$cmd" &>/dev/null; then
    error "Required command not found: $cmd"
  fi
done
ok "All required commands found"

# ============================================================
# STEP 2: Backup current configuration
# ============================================================
step "STEP 2 — Backing up current configuration"

mkdir -p "$BACKUP_DIR"
log "Backup directory: $BACKUP_DIR"

BACKED_UP=0
for file in configuration.nix flake.nix hardware-configuration.nix home.nix; do
  if [ -f "$NIXOS_DIR/$file" ]; then
    cp "$NIXOS_DIR/$file" "$BACKUP_DIR/"
    ok "Backed up: $file"
    BACKED_UP=$((BACKED_UP + 1))
  else
    warn "Not found (skipping): $file"
  fi
done

ok "Backup complete ($BACKED_UP files saved to $BACKUP_DIR)"

# ============================================================
# RESTORE FUNCTION (used on failure)
# ============================================================
restore_backup() {
  warn "Restoring backup..."
  # Restore all 4 files including hardware-configuration.nix
  for file in configuration.nix flake.nix home.nix hardware-configuration.nix; do
    if [ -f "$BACKUP_DIR/$file" ]; then
      cp "$BACKUP_DIR/$file" "$NIXOS_DIR/"
      ok "Restored: $file"
    fi
  done
  warn "Files restored. Rebuilding previous configuration..."
  cd "$NIXOS_DIR"
  nixos-rebuild switch --flake .#km-laptop || warn "Rebuild of previous config failed. Reboot may be needed."
  warn "Previous configuration is active again."
}

# ============================================================
# STEP 3: Enable Flakes support
# ============================================================
step "STEP 3 — Enabling Flakes support"

NIX_CONF="/etc/nix/nix.conf"
mkdir -p /etc/nix

if grep -q "experimental-features" "$NIX_CONF" 2>/dev/null; then
  if ! grep -q "nix-command" "$NIX_CONF" || ! grep -q "flakes" "$NIX_CONF"; then
    sed -i 's/^experimental-features.*/experimental-features = nix-command flakes/' "$NIX_CONF"
    ok "Flakes line updated"
  else
    ok "Flakes already enabled"
  fi
else
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
  ok "Flakes enabled"
fi

# ============================================================
# STEP 4: Download configuration files to /tmp
# ============================================================
step "STEP 4 — Downloading configuration files"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

DOWNLOAD_FAILED=0
for file in "${FILES[@]}"; do
  log "Downloading $file..."
  if curl -fsSL --retry 3 --retry-delay 2 "$REPO/$file" -o "$TMP_DIR/$file"; then
    if [ -s "$TMP_DIR/$file" ]; then
      ok "Downloaded: $file"
    else
      warn "Downloaded but empty: $file"
      DOWNLOAD_FAILED=1
    fi
  else
    warn "Failed to download: $file"
    DOWNLOAD_FAILED=1
  fi
done

if [ "$DOWNLOAD_FAILED" -ne 0 ]; then
  rm -rf "$TMP_DIR"
  error "One or more files failed to download. Aborting. System is untouched."
fi

ok "All files downloaded to $TMP_DIR"

# ============================================================
# STEP 5: Validate downloaded files
# ============================================================
step "STEP 5 — Validating configuration"

# Copy hardware-configuration.nix to tmp for flake evaluation
if [ -f "$NIXOS_DIR/hardware-configuration.nix" ]; then
  cp "$NIXOS_DIR/hardware-configuration.nix" "$TMP_DIR/"
  ok "hardware-configuration.nix copied to temp dir"
else
  error "hardware-configuration.nix not found. Please generate it manually first:\n       sudo nixos-generate-config\n       Then re-run this script."
fi

log "Running flake validation..."
if ! nix flake show "$TMP_DIR" --no-write-lock-file 2>/dev/null; then
  rm -rf "$TMP_DIR"
  error "Flake validation failed. Aborting. System is untouched."
fi
ok "Flake validation passed"

# ============================================================
# STEP 6: Replace configuration files
# ============================================================
step "STEP 6 — Installing configuration files"

for file in "${FILES[@]}"; do
  cp "$TMP_DIR/$file" "$NIXOS_DIR/"
  ok "Installed: $file"
done

if [ ! -f "$NIXOS_DIR/hardware-configuration.nix" ]; then
  cp "$TMP_DIR/hardware-configuration.nix" "$NIXOS_DIR/"
  ok "Installed: hardware-configuration.nix"
fi

ok "All configuration files installed"

# ============================================================
# STEP 7: First evaluation pass (dry-build)
# ============================================================
step "STEP 7 — First evaluation pass"

log "Running dry-build evaluation..."
cd "$NIXOS_DIR"

if ! nixos-rebuild dry-build --flake .#km-laptop 2>&1; then
  warn "Dry-build evaluation failed."
  restore_backup
  error "Aborting after restore."
fi

ok "Dry-build passed"

# ============================================================
# STEP 8: Test activation (without changing boot)
# ============================================================
step "STEP 8 — Test activation"

log "Running nixos-rebuild test (no permanent boot change)..."

if ! nixos-rebuild test --flake .#km-laptop 2>&1; then
  warn "Test activation failed."
  restore_backup
  error "Aborting after restore."
fi

ok "Test activation passed"

# ============================================================
# STEP 9: Permanent activation
# ============================================================
step "STEP 9 — Permanent activation"

log "Running nixos-rebuild switch..."

if ! nixos-rebuild switch --flake .#km-laptop 2>&1; then
  warn "Switch failed."
  restore_backup
  error "Aborting after restore."
fi

ok "System switched successfully"

# Generation cleanup (only after successful switch)
log "Cleaning up old generations (keeping last 14 days)..."
nix-collect-garbage --delete-older-than 14d 2>/dev/null || true
ok "Generation cleanup done"

# ============================================================
# STEP 10: Verify SSH remains accessible
# ============================================================
step "STEP 10 — Verifying SSH access"

if systemctl is-active sshd &>/dev/null; then
  ok "SSH is active and running"
else
  warn "SSH appears inactive. Attempting restart..."
  if systemctl restart sshd; then
    ok "SSH restarted successfully"
  else
    warn "Could not restart SSH. Check manually: systemctl status sshd"
  fi
fi

# Cleanup temp
rm -rf "$TMP_DIR"

# ============================================================
# STEP 11: Final report
# ============================================================
step "STEP 11 — Final Report"

GENERATION=$(nixos-rebuild list-generations 2>/dev/null | grep current || readlink /nix/var/nix/profiles/system 2>/dev/null || echo "unknown")
SSH_STATUS=$(systemctl is-active sshd 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Installation completed successfully  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Active generation: ${CYAN}$GENERATION${NC}"
echo -e "  Backup saved at:   ${CYAN}$BACKUP_DIR${NC}"
echo -e "  SSH status:        ${GREEN}$SSH_STATUS${NC}"
echo ""
echo -e "  ${YELLOW}You may now reboot into Hyprland:${NC}"
echo -e "  ${CYAN}sudo reboot${NC}"
echo ""
