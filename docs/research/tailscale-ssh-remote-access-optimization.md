# Tailscale SSH & Remote Access Optimization

> **Researched**: 2026-03-17
> **Review by**: 2026-09-17
> **Sources**: 4 parallel research agents (Tailscale docs, mosh project, tmux wiki, macOS pmset man pages, ntfy.sh docs)
> **Scope**: Optimizations for SSH over Tailscale on macOS — resilience, clipboard, security, persistence, performance

---

## Quick Reference — Decision Rules

| Situation | Action |
|-----------|--------|
| SSH to macOS from anywhere | Use standard SSH over Tailscale (not Tailscale SSH — Homebrew can't intercept port 22) |
| Resilient terminal sessions | Use mosh + tmux (survives Wi-Fi drops, sleep/wake, roaming) |
| Clipboard over SSH | Enable OSC 52 in tmux (`set -s set-clipboard on`, `allow-passthrough on`) + WezTerm supports it natively |
| Prevent lockout while traveling | Disable key expiry on Mac server in Tailscale admin console |
| Restrict SSH to Tailscale only | Use pf firewall rules (macOS launchd ignores `ListenAddress` in sshd_config) |
| Brute force protection | Not needed — Tailscale eliminates public attack surface |
| Survive reboots | Install tmux-resurrect + tmux-continuum plugins |
| Always-on Mac for remote access | `sudo pmset -c sleep 0 standby 0 autopoweroff 0 ttyskeepawake 1` |
| SSH login alerts | PAM + ntfy.sh notification script |
| tmux -CC (iTerm2 integration) | Use Eternal Terminal instead of mosh |

---

## Hard Constraints

- **Never** use `ForwardAgent yes` — a compromised host can use your agent to authenticate elsewhere
- **Always** use ed25519 keys (not RSA, not ecdsa)
- **Never** rely on Power Nap for remote access — it does not keep the Mac continuously awake

---

## Deep Reference

### 1. mosh — Resilient Terminal Sessions

mosh (mobile shell) maintains a connection through Wi-Fi drops, IP changes, sleep/wake cycles, and roaming between networks. It runs UDP on ports 60000–61000 and uses SSH only for initial key exchange.

**Install and connect**:

```bash
# Install on both the server (Mac) and client
brew install mosh

# Connect with mosh, landing in a named tmux session
mosh user@infinity.cinnebar-alhena.ts.net -- tmux new-session -As claude
```

The `-As claude` flag attaches to an existing session named `claude` or creates it if it doesn't exist.

**Tailscale note**: mosh connects over Tailscale just like SSH — use the MagicDNS hostname. Ensure UDP 60000–61000 is reachable on the server (Tailscale passes UDP through by default).

**mosh limitations**:
- No scrollback buffer (tmux compensates)
- No SSH agent forwarding (use a key on the remote machine for git operations)
- No OSC 52 clipboard passthrough (mosh doesn't relay escape sequences)
- No tmux -CC integration (use Eternal Terminal if you need iTerm2 native panes)

**mosh vs SSH comparison**:

| Feature | SSH | mosh |
|---------|-----|------|
| Survives network change | No | Yes |
| Survives sleep/wake | No (drops) | Yes |
| Scrollback | Via tmux | Via tmux only |
| Clipboard (OSC 52) | Yes (via tmux) | No |
| SSH agent forwarding | Yes | No |
| Protocol | TCP | UDP |
| iTerm2 -CC integration | No | No (use ET) |

---

### 2. OSC 52 Clipboard

OSC 52 is a terminal escape sequence that lets a remote process write to your local clipboard. With it, `pbcopy`-style operations work transparently over SSH without X forwarding.

**tmux configuration** (add to `~/.tmux.conf`):

```bash
# Allow tmux to forward OSC 52 sequences to the outer terminal
set -s set-clipboard on
set -g allow-passthrough on
```

`set-clipboard on` tells tmux to use OSC 52 when it copies to its own clipboard. `allow-passthrough on` allows applications inside tmux panes to send escape sequences through tmux to the outer terminal — this is what enables the remote clipboard write to reach WezTerm.

**WezTerm**: Supports OSC 52 natively with no configuration. Clipboard writes from remote processes appear in the local clipboard immediately.

**osc52copy helper script** — paste into your remote shell config:

```bash
# ~/.config/fish/functions/osc52copy.fish  (or adapt for bash/zsh)
function osc52copy
    printf "\033]52;c;%s\a" (printf '%s' $argv | base64)
end
```

Usage: `echo "text to copy" | osc52copy`

**Why mosh doesn't work**: mosh intercepts and strips unknown escape sequences (including OSC 52) for protocol safety reasons. If you need clipboard over a resilient connection, use SSH + tmux rather than mosh.

---

### 3. SSH Login Notifications

Get a push notification on your phone whenever someone (or something) SSHs into your Mac. Uses PAM (Pluggable Authentication Modules) to run a script on session open.

**Step 1: Create the notification script**

```bash
sudo tee /usr/local/bin/ssh-notify.sh > /dev/null << 'EOF'
#!/bin/bash
# SSH login notification via ntfy.sh
# PAM provides: PAM_USER, PAM_RHOST, PAM_TYPE

if [ "$PAM_TYPE" = "open_session" ]; then
    HOSTNAME=$(hostname -s)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    MESSAGE="SSH login: ${PAM_USER} from ${PAM_RHOST:-local} on ${HOSTNAME} at ${TIMESTAMP}"

    curl -s -o /dev/null \
        -H "Title: SSH Login Alert" \
        -H "Priority: default" \
        -H "Tags: computer,key" \
        -d "$MESSAGE" \
        https://ntfy.sh/YOUR_TOPIC_NAME
fi
EOF

sudo chmod +x /usr/local/bin/ssh-notify.sh
```

Replace `YOUR_TOPIC_NAME` with a hard-to-guess string (e.g., `infinity-ssh-abc123`). Subscribe to this topic in the ntfy iOS/Android app.

**Step 2: Register with PAM**

```bash
sudo nano /etc/pam.d/sshd
```

Add this line at the end:

```
session optional pam_exec.so /usr/local/bin/ssh-notify.sh
```

`optional` means SSH login succeeds even if the script fails (network outage, etc.).

**Step 3: Test**

```bash
# Trigger a test notification without logging in
sudo PAM_TYPE=open_session PAM_USER=testuser PAM_RHOST=10.0.0.1 /usr/local/bin/ssh-notify.sh
```

**ntfy.sh note**: ntfy.sh is free for self-hosted or limited public use. For a self-hosted alternative, run ntfy in Docker on your Unraid server and change the URL to `http://unraid:8080/YOUR_TOPIC`.

---

### 4. pf Firewall Rules — Restrict SSH to Tailscale Only

macOS launchd (the SSH daemon manager) ignores `ListenAddress` in `sshd_config`. The only reliable way to restrict SSH to the Tailscale interface is via the `pf` packet filter.

**Why `ListenAddress` doesn't work on macOS**: macOS uses launchd socket activation for sshd. The socket is created by launchd before sshd starts, and launchd binds to `0.0.0.0:22` regardless of `sshd_config`. The `ListenAddress` directive is only respected when sshd manages its own sockets (Linux behavior).

**pf rules**:

Create `/etc/pf.anchors/tailscale-ssh`:

```
# Allow SSH from Tailscale CGNAT range (100.64.0.0/10) on the Tailscale interface
pass in on utun0 proto tcp from 100.64.0.0/10 to any port 22

# Block SSH from all other sources
block in proto tcp from any to any port 22
```

> **Note**: `utun0` is typical for Tailscale on macOS but may be `utun1` or `utun2` if other VPN software is installed. Verify with `tailscale debug netmap | grep -i utun` or check `ifconfig | grep utun`.

**Load the anchor**:

```bash
# Add to /etc/pf.conf (before the last "pass" rule)
anchor "tailscale-ssh"
load anchor "tailscale-ssh" from "/etc/pf.anchors/tailscale-ssh"

# Enable pf and load rules
sudo pfctl -ef /etc/pf.conf
```

**Make it persistent across reboots**:

```bash
# pf is controlled by launchd on macOS
# Enable pf to load at boot:
sudo pfctl -e   # enable now

# Edit /etc/pf.conf and add the anchor lines above
# pf.conf is loaded automatically at boot by com.apple.pfctl
```

**Verify**:

```bash
# Check pf is running
sudo pfctl -s info | grep -i status

# Check SSH is blocked from non-Tailscale addresses
# From a device NOT on Tailscale, try: ssh user@<LAN-IP>
# Should get: "Connection refused" or timeout
```

---

### 5. tmux Session Persistence — Resurrect + Continuum

tmux sessions die if the Mac reboots. `tmux-resurrect` saves and restores sessions. `tmux-continuum` automates the save/restore cycle.

**Install TPM (Tmux Plugin Manager)**:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

**tmux.conf additions**:

```bash
# === Plugin Manager (TPM) ===
# Install: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Session persistence — save/restore sessions across reboots
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Continuum: auto-save every 15 minutes
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# Resurrect: restore pane contents (optional, requires shell history)
set -g @resurrect-capture-pane-contents 'on'

# Initialize TPM — keep this at the very end of tmux.conf
run '~/.tmux/plugins/tpm/tpm'
```

**First-time plugin install**: After adding the config, start tmux and press `Prefix + I` (capital I) to fetch the plugins.

**Manual save/restore**:
- `Prefix + Ctrl+S` — save session state
- `Prefix + Ctrl+R` — restore session state

**Auto-start tmux on boot via launchd**:

Create `~/Library/LaunchAgents/com.user.tmux-start.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.tmux-start</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/tmux</string>
        <string>new-session</string>
        <string>-d</string>
        <string>-s</string>
        <string>claude</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/tmux-start.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/tmux-start.err</string>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.user.tmux-start.plist
```

With tmux-continuum's `@continuum-restore 'on'`, the first new tmux session after boot will automatically restore the saved session state.

---

### 6. Always-On Mac — pmset Configuration

For a Mac that serves as a remote access node, prevent it from sleeping on AC power.

**Full command**:

```bash
sudo pmset -c sleep 0 standby 0 autopoweroff 0 ttyskeepawake 1 womp 1
```

**Flag breakdown**:

| Flag | Value | Effect |
|------|-------|--------|
| `-c` | (scope) | Apply only when on AC power (not battery) |
| `sleep` | `0` | Disable system sleep on AC |
| `standby` | `0` | Disable standby mode (deep sleep after sleep) |
| `autopoweroff` | `0` | Disable autopoweroff (macOS standby variant on newer hardware) |
| `ttyskeepawake` | `1` | Stay awake while any SSH/TTY session is active |
| `womp` | `1` | Wake on Magic Packet (for WoL via Unraid relay) |

**Important caveats**:
- `-c` means this only applies when plugged into AC power. On battery, normal sleep rules apply — the Mac will sleep if unplugged
- `ttyskeepawake 1` keeps the Mac awake during an active SSH session but doesn't prevent sleep when no session is active. Combine with `sleep 0` for truly always-on behavior
- **Never** use `sudo pmset -a disablesleep 1` on a laptop — this prevents even battery-critical sleep

**Verify settings**:

```bash
pmset -g    # show all power management settings
```

**Why Power Nap is not sufficient**: Power Nap briefly wakes the Mac for Mail, iCloud sync, and Time Machine. It does not maintain a continuous network stack — Tailscale will not respond and SSH connections will not be accepted during Power Nap wake intervals. Use `sleep 0` for reliable remote access.

---

### 7. Tailscale Exit Nodes — Secure Browsing on Public Wi-Fi

An exit node routes all non-Tailscale internet traffic through a specific device in your tailnet. When you use your home Mac as an exit node, your traffic from coffee shops, hotels, and airports exits from your home IP — bypassing captive portals and hostile network monitoring.

**Advertise your Mac as an exit node**:

```bash
sudo tailscale up --advertise-exit-node
```

**Approve the exit node in the admin console**:

Go to https://login.tailscale.com/admin/machines → find Infinity → Edit route settings → check "Use as exit node".

**Use the exit node from another device**:

```bash
# Route all traffic through Infinity (your Mac)
sudo tailscale up --exit-node=infinity

# Stop using the exit node
sudo tailscale up --exit-node=
```

Or use the Tailscale app → Exit Nodes → select `infinity`.

**Subnet routes**: You can also advertise subnets (e.g., your home LAN `192.168.1.0/24`) alongside the exit node:

```bash
sudo tailscale up --advertise-exit-node --advertise-routes=192.168.1.0/24
```

---

### 8. Tailscale Funnel — Webhook Development

Tailscale Funnel exposes a local port to the public internet at a stable HTTPS URL. Unlike ngrok (random URLs, rate-limited tunnels), Funnel uses your MagicDNS hostname — the URL is always `https://infinity.cinnebar-alhena.ts.net/`.

```bash
# Expose local port 3000 to the public internet
tailscale funnel 3000

# Your webhook endpoint is now:
# https://infinity.cinnebar-alhena.ts.net/

# Stop when done
tailscale funnel off
```

**Use cases**:
- Receiving Stripe/GitHub/Shopify webhooks during local development
- Sharing a dev build with a client without deploying
- OAuth callback URLs for testing third-party integrations

**Requirements**: Homebrew formula install (`brew install tailscale`) — Funnel is not available with the App Store or cask version.

**Security**: Funnel is public — anyone on the internet can reach it. Turn it off when not in active use. For private sharing (tailnet only), use `tailscale serve` instead.

---

### 9. FIDO2 / Secure Enclave SSH Keys

Hardware-backed SSH keys that cannot be exported — the private key never leaves the security chip.

**Option A: FIDO2 hardware key (YubiKey / Passkey)**

macOS ships with an older version of OpenSSH that lacks `sk-ed25519` support. Install the Homebrew version:

```bash
brew install openssh

# Generate a hardware-bound ed25519 key
/opt/homebrew/bin/ssh-keygen -t ed25519-sk -f ~/.ssh/id_ed25519_sk

# The key requires physical touch on the YubiKey to sign
# Even if the .pub and stub files are stolen, the key is unusable without the hardware
```

**Option B: macOS Secure Enclave (T2 / M-series)**

```bash
# Create a Secure Enclave-backed identity (requires macOS 13.4+)
sc_auth create-ctk-identity -l "SSH Key (Secure Enclave)"

# List available smart card identities
sc_auth list
```

The Secure Enclave key is tied to the device. It cannot be extracted or copied — even a full disk image won't yield the key.

**Comparison**:

| Method | Hardware Required | Portable | Survives Disk Clone |
|--------|------------------|----------|---------------------|
| ed25519 (standard) | No | Yes | Yes |
| ed25519-sk (FIDO2) | YubiKey | Yes (key travels with you) | No (stub file useless without hardware) |
| Secure Enclave | Built-in (M1+) | No | No |

---

### 10. Tailscale Peer Relays (2025) — Performance Notes

As of 2025, Tailscale introduced UDP-based peer relays as an upgrade path over DERP (Designated Encrypted Relay for Packets) for international and high-latency connections.

**Performance benchmarks** (observed):

| Connection type | Bandwidth | Latency |
|-----------------|-----------|---------|
| Direct P2P (same LAN) | Full line rate | <5ms |
| Direct P2P (same city) | Full line rate | 5–20ms |
| DERP relay (international) | ~2.2 Mbps sustained | 80–200ms |
| Peer relay (UDP, 2025) | 27–35 Mbps sustained | 40–120ms |

**When you get DERP vs direct**:
- DERP is used when NAT traversal fails (symmetric NAT, CGNAT, strict firewall)
- Direct P2P is used when UDP hole punching succeeds
- Peer relays are a middle tier available when direct P2P fails but full DERP throughput is insufficient

**Check your connection type**:

```bash
tailscale ping --c 5 infinity
# "via DERP(nyc)" = DERP relay
# "via 192.168.x.x:41641" = direct P2P
# "via relay-..." = peer relay
```

**Improve direct connection rate**:
- Ensure UDP 41641 is allowed outbound on both sides
- On a router with symmetric NAT, enable UPnP or manually forward UDP 41641
- `tailscale debug peer-endpoint-changes` to see NAT traversal attempts

---

## Related

- [Remote Claude Code Access via Tailscale](../../Projects/docs/remote-claude-code-tailscale-guide.md) — full setup guide
- [Dotfiles Chezmoi Architecture](dotfiles-chezmoi-architecture.md) — how these configs are managed
- [Tailscale KB: SSH](https://tailscale.com/kb/1193/tailscale-ssh)
- [mosh project](https://mosh.org/)
- [ntfy.sh documentation](https://ntfy.sh/docs/)
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)
