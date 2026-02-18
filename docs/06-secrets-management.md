# Secrets Management

Handling sensitive data like API keys, private tokens, or personal email addresses requires caution. Since dotfile repositories are often public or shared, you shouldn't commit raw secrets to version control.

## Why Secrets Need Special Handling

Committing secrets to Git is a security risk. Even if a repository is private, secrets can leak through history or local backups. This setup uses Chezmoi's templating system to keep secrets separate from the logic of your configuration.

## The `.chezmoidata/secrets.yml` Approach

The preferred method for managing secrets in this repository is using a local data file that Chezmoi reads but Git ignores.

1. Create the directory if it doesn't exist: `mkdir -p ~/.config/chezmoi/.chezmoidata`
2. Create a file named `secrets.yml` in that directory.
3. Add your secrets in YAML format:

```yaml
email: "user@example.com"
github_token: "ghp_your_secret_token"
ssh_key_path: "~/.ssh/id_ed25519"
```

This file is automatically added to `.gitignore` to ensure it never gets pushed to the remote repository.

## Using Templates with Secrets

Once you define a secret in `secrets.yml`, you can use it in any file with a `.tmpl` extension.

Example for a `.gitconfig.tmpl`:

```ini
[user]
    name = Your Name
    email = {{ .email }}
```

## Alternative: Password Managers

For a more robust setup, Chezmoi integrates directly with various password managers. This is safer than plain text files because the secrets are encrypted at rest.

### 1Password

You can retrieve values using the `onepassword` template function:

```bash
{{ (onepasswordItemFields "GitHub Token").password.value }}
```

### Bitwarden

Use the `bitwarden` CLI integration:

```bash
{{ (bitwarden "item" "my-secret-item").login.password }}
```

## What NOT to Commit

*   Plain text API keys
*   Private SSH keys
*   OAuth tokens
*   Personal phone numbers or home addresses
*   Encryption passphrases

## Example: SSH Config with Secrets

If you have different SSH configurations for work and personal use, you can template your `~/.ssh/config.tmpl`:

```text
Host github.com
    HostName github.com
    User git
    IdentityFile {{ .ssh_key_path }}
```

By keeping the path in `secrets.yml`, you can use different keys on different machines without changing the tracked code.

---

[Next: Platform Specific Notes](07-platform-specific.md)
