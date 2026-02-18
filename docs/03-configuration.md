# Configuration and Templates

This guide explains how this dotfiles repository uses Chezmoi templates to manage configuration across different operating systems and environments.

## How the Template System Works

Chezmoi uses the [text/template](https://pkg.go.dev/text/template) syntax from Go. Any file ending in `.tmpl` is processed by Chezmoi before being written to your home directory. This allows for dynamic content based on your OS, hostname, or custom variables.

### OS Detection

We use the built-in `.chezmoi.os` variable to handle platform-specific configurations. This ensures your setup works seamlessly on macOS, Linux, and Windows (WSL2).

Example pattern:

```go
{{- if eq .chezmoi.os "darwin" }}
# macOS specific config
alias ls='ls -G'
{{- else if eq .chezmoi.os "linux" }}
# Linux specific config
alias ls='ls --color=auto'
{{- end }}
```

### Reading .tmpl Files

When you see a `.tmpl` file in the source repository, look for these common elements:

- `{{ ... }}`: Actions or variables.
- `{{- ... -}}`: Actions that trim surrounding whitespace.
- `{{ if ... }} ... {{ end }}`: Conditional blocks.
- `{{ .variable }}`: Accessing data or variables.

## Common Template Patterns

### Environment Variables

We often use templates to set paths based on the operating system:

```bash
export PROJECTS="{{ .chezmoi.homeDir }}/Projects"
```

### Conditional Tool Loading

If a tool is only available or needed on a specific platform:

```bash
{{- if (stat "/usr/local/bin/brew") }}
eval "$(/usr/local/bin/brew shellenv)"
{{- end }}
```

## Customizing Without Breaking Updates

To keep your fork up to date with the upstream repository while maintaining personal tweaks, follow these rules:

1. **Use Local Files**: Put personal aliases in `~/.zshrc.local` if the template includes it.
2. **Template Variables**: Use a `.chezmoidata.yaml` file for personal information like email or API keys.
3. **Avoid Editing Core Templates**: Try to use the customization hooks described in [Personalizing Your Setup](04-customization.md).

## Examples of Template Usage

### Shell Aliases

Our shell configuration uses templates to provide consistent aliases while accounting for tool availability:

```bash
{{- if lookPath "eza" }}
alias ls='eza --icons'
{{- else }}
alias ls='ls --color=auto'
{{- end }}
```

### Git Configuration

We use templates to set your Git identity dynamically:

```ini
[user]
    name = {{ .name | quote }}
    email = {{ .email | quote }}
```

Next: [Personalizing Your Setup](04-customization.md)
