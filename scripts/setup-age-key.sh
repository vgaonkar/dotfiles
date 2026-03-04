#!/usr/bin/env bash
# setup-age-key.sh — Bootstrap age encryption key for chezmoi secrets
# Usage: bash scripts/setup-age-key.sh

set -euo pipefail

KEY_DIR="${HOME}/.config/chezmoi"
KEY_FILE="${KEY_DIR}/key.txt"

# Ensure age is available
if ! command -v age-keygen &>/dev/null; then
  echo "ERROR: age-keygen not found. Install age first:" >&2
  echo "  brew install age        # macOS" >&2
  echo "  apt install age         # Debian/Ubuntu" >&2
  exit 1
fi

# Create the directory with restricted permissions
mkdir -p "${KEY_DIR}"
chmod 700 "${KEY_DIR}"

# Generate the key only if it does not already exist
if [[ -f "${KEY_FILE}" ]]; then
  echo "Age identity already exists at: ${KEY_FILE}"
else
  age-keygen -o "${KEY_FILE}"
  chmod 600 "${KEY_FILE}"
  echo "Age identity generated at: ${KEY_FILE}"
fi

# Extract and display the public key
PUBLIC_KEY="$(grep "^# public key:" "${KEY_FILE}" | awk '{print $NF}')"

echo ""
echo "=== Your age public key (recipient) ==="
echo "${PUBLIC_KEY}"
echo ""
echo "Next steps:"
echo "  1. Copy the public key above."
echo "  2. Open .chezmoi.toml.tmpl and set the [age] recipient field:"
echo "       recipient = \"${PUBLIC_KEY}\""
echo "  3. Encrypt secrets with:"
echo "       chezmoi age encrypt secrets.yml > private_dot_config/chezmoi/secrets.yml.age"
echo "  4. Never commit ~/.config/chezmoi/key.txt — keep it backed up securely."
