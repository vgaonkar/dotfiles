# Popular Starship Color Themes

## Top 10 Most Popular Themes

### 1. **Catppuccin** ⭐ (Currently Using)
- **Style**: Warm pastel colors
- **Variants**: Mocha (dark), Macchiato, Frappe, Latte (light)
- **Colors**: Pinks, mauves, blues, peaches
- **Best for**: Daily use, easy on eyes
- **Your current**: Mocha variant

### 2. **Tokyo Night** 🌃
- **Style**: Modern, dark purples/blues
- **Colors**: Deep blues, purples, pinks, cyans
- **Best for**: Late night coding, modern aesthetic
- **Vibe**: Cyberpunk/Neon city at night

### 3. **Nord** ❄️
- **Style**: Arctic, cool colors
- **Colors**: Blues, cyans, snowy whites
- **Best for**: Clean, professional look
- **Vibe**: Polar ice, minimal

### 4. **Dracula** 🧛
- **Style**: Vibrant, high contrast
- **Colors**: Purples, pinks, greens, cyan
- **Best for**: High visibility, accessibility
- **Vibe**: Classic dark theme

### 5. **Gruvbox** 🟤
- **Style**: Retro, warm
- **Colors**: Browns, yellows, oranges, greens
- **Best for**: Vintage feel, reduced eye strain
- **Vibe**: Old school terminal

### 6. **One Dark** ⚫
- **Style**: GitHub/Atom editor theme
- **Colors**: Dark grays, reds, greens, blues
- **Best for**: Familiar, professional

### 7. **Solarized** 🌅
- **Style**: Scientific, carefully selected
- **Variants**: Dark, Light
- **Colors**: Selective palette for readability
- **Best for**: Consistent across apps

### 8. **Everforest** 🌲
- **Style**: Nature-inspired, muted
- **Colors**: Greens, browns, soft colors
- **Best for**: Relaxed, natural feel

### 9. **Kanagawa** 🌊
- **Style**: Japanese-inspired
- **Colors**: Deep blues, wave colors
- **Best for**: Unique, artistic
- **Vibe**: Traditional Japanese art

### 10. **Rose Pine** 🌸
- **Style**: Soft, warm pastels
- **Colors**: Pinks, roses, warm tones
- **Best for**: Gentle, feminine aesthetic

---

## Single-Line Full Detail Config

Save this to `~/.config/starship.toml`:

```toml
# Single-Line Full Information Starship Config
add_newline = false

# Everything on one line: OS → User → Dir → Git → Languages → Status → Prompt
format = "$os$username$directory$git_branch$git_status$nodejs$python$golang$rust$java$ruby$cmd_duration$character"

# Theme: Tokyo Night Storm (single-line optimized)
[os]
disabled = false
style = "fg:#7aa2f7"
format = "[$symbol ]($style)"

[os.symbols]
Ubuntu = "󰕈"
Linux = "󰌽"
Macos = "󰀵"
Windows = "󰍲"

[username]
show_always = false
style_user = "fg:#bb9af7"
format = "[$user@]($style)"

[directory]
style = "fg:#7dcfff"
format = "[$path]($style) "
truncation_length = 2
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "📄 "
"Downloads" = "⬇️ "
"Music" = "🎵 "
"Pictures" = "🖼️ "
"Projects" = "💻 "

[git_branch]
symbol = ""
style = "fg:#ff9e64"
format = "[on $branch]($style) "

[git_status]
style = "fg:#ff9e64"
format = "([$all_status$ahead_behind]($style) )"
conflicted = "⚠️"
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕"
up_to_date = ""
untracked = "?${count}"
stashed = "📦"
modified = "!${count}"
staged = "+${count}"
renamed = "»${count}"
deleted = "✘${count}"

[nodejs]
symbol = ""
style = "fg:#9ece6a"
format = "[Node($version)]($style) "
disabled = false

[python]
symbol = ""
style = "fg:#e0af68"
format = "[Py($version)]($style) "
disabled = false

[golang]
symbol = ""
style = "fg:#7aa2f7"
format = "[Go($version)]($style) "
disabled = false

[rust]
symbol = ""
style = "fg:#f7768e"
format = "[Rust($version)]($style) "
disabled = false

[java]
symbol = ""
style = "fg:#e0af68"
format = "[Java($version)]($style) "
disabled = false

[ruby]
symbol = ""
style = "fg:#f7768e"
format = "[Ruby($version)]($style) "
disabled = false

[cmd_duration]
min_time = 2000
style = "fg:#565f89"
format = "[in $duration]($style) "

[character]
success_symbol = "[❯](fg:#9ece6a)"
error_symbol = "[❯](fg:#f7768e)"
```

---

## Example Output

**Normal directory:**
```
󰕈 ~/Documents ❯
```

**Git repo:**
```
󰕈 ~/Projects/myapp on main Node(v20.5.0) Py(3.11.0) ⇡2 !3 ❯
```

**Long running command:**
```
󰕈 ~/Projects/myapp on main Node(v20.5.0) in 5.2s ❯
```

---

## Quick Theme Switcher

Add to your `~/.config/fish/config.fish`:

```fish
# Starship theme switcher
function starship-theme
    switch $argv[1]
        case tokyo
            curl -s https://starship.rs/presets/tokyo-night.toml -o ~/.config/starship.toml
            echo "🌃 Tokyo Night theme applied"
        case catppuccin
            curl -s https://starship.rs/presets/catppuccin.toml -o ~/.config/starship.toml
            echo "☕ Catppuccin theme applied"
        case nord
            curl -s https://starship.rs/presets/nord.toml -o ~/.config/starship.toml
            echo "❄️ Nord theme applied"
        case dracula
            curl -s https://starship.rs/presets/dracula.toml -o ~/.config/starship.toml
            echo "🧛 Dracula theme applied"
        case gruvbox
            curl -s https://starship.rs/presets/gruvbox-rainbow.toml -o ~/.config/starship.toml
            echo "🟤 Gruvbox theme applied"
        case minimal
            echo 'format = "$directory$git_branch$character"' > ~/.config/starship.toml
            echo "⚡ Minimal theme applied"
        case '*'
            echo "Available themes: tokyo, catppuccin, nord, dracula, gruvbox, minimal"
    end
end
```

Then use:
```bash
starship-theme tokyo      # Switch to Tokyo Night
starship-theme catppuccin # Switch to Catppuccin
starship-theme minimal    # Switch to minimal
```

---

## Comparison Table

| Theme | Colors | Best For | Mood |
|-------|--------|----------|------|
| **Catppuccin** | Pastel pinks, blues | Daily use | Cozy, modern |
| **Tokyo Night** | Purples, blues | Night coding | Cyberpunk |
| **Nord** | Cool blues | Professional | Clean, icy |
| **Dracula** | Vibrant purples | Visibility | Classic dark |
| **Gruvbox** | Warm browns | Eye comfort | Retro |
| **One Dark** | Grays, reds | GitHub users | Familiar |
| **Solarized** | Controlled palette | Consistency | Scientific |

---

## Recommendation

For **single-line full detail**, try:
1. **Tokyo Night** - Modern, distinct colors for each element
2. **Catppuccin Mocha** - Soft but readable (your current)
3. **Nord** - Professional, clean separation

The Tokyo Night single-line config above shows:
- OS icon (colored)
- Directory (cyan)
- Git branch (orange)
- Git status (orange with symbols)
- Language versions (green for Node, yellow for Python, etc.)
- Execution time (gray, only if >2s)
- Clean prompt character (green=success, red=error)

All on one line! 🚀
