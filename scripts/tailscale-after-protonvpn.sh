#!/usr/bin/env bash
# tailscale-after-protonvpn.sh — Restart Tailscale after ProtonVPN connects
#
# ProtonVPN must CONNECT before Tailscale starts for SSH to work through the VPN.
# On reboot, tailscaled (LaunchDaemon) starts before ProtonVPN (login app),
# so this script waits for ProtonVPN's WireGuard tunnel to be active, then
# restarts Tailscale.
#
# Installed as a LaunchAgent so it runs at user login.

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

LOG="/tmp/tailscale-after-protonvpn.log"
MAX_WAIT=180  # seconds to wait for ProtonVPN to connect

echo "[$(date)] Waiting for ProtonVPN to connect..." >> "$LOG"

elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
  # Check for ProtonVPN's WireGuard system extension — this only runs when connected
  if pgrep -f "ch.protonvpn.mac.WireGuard-Extension" > /dev/null 2>&1; then
    echo "[$(date)] ProtonVPN WireGuard tunnel active (after ${elapsed}s). Restarting Tailscale..." >> "$LOG"

    # Restart Tailscale so it configures routes around ProtonVPN
    brew services stop tailscale >> "$LOG" 2>&1 || true
    sleep 2
    brew services start tailscale >> "$LOG" 2>&1 || true
    sleep 5

    # Re-enable SSH and exit node
    tailscale up --ssh --advertise-exit-node >> "$LOG" 2>&1 || true

    echo "[$(date)] Tailscale restarted after ProtonVPN. SSH should be accessible." >> "$LOG"
    exit 0
  fi

  sleep 5
  elapsed=$((elapsed + 5))
done

echo "[$(date)] ProtonVPN not connected after ${MAX_WAIT}s. Tailscale running as-is." >> "$LOG"
# Still ensure SSH is enabled even without ProtonVPN
tailscale up --ssh --advertise-exit-node >> "$LOG" 2>&1 || true
