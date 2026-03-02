#!/usr/bin/env python3
"""Generate SVG fake-terminal screenshots for dotfiles README."""

import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WIDTH, HEIGHT = 900, 500

# Catppuccin Macchiato palette
C = {
    "base": "#24273a",
    "surface0": "#363a4f",
    "surface1": "#494d64",
    "text": "#cad3f5",
    "subtext": "#a5adcb",
    "blue": "#8aadf4",
    "green": "#a6da95",
    "yellow": "#eed49f",
    "red": "#ed8796",
    "mauve": "#c6a0f6",
    "peach": "#f5a97f",
    "teal": "#8bd5ca",
    "pink": "#f5bde6",
    "flamingo": "#f0c6c6",
}

FONT = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', monospace"
LINE_H = 20
CHAR_W = 8.4
PAD_X, PAD_Y = 20, 50


def svg_header(title: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
  <rect width="{WIDTH}" height="{HEIGHT}" rx="8" fill="{C['base']}"/>
  <!-- title bar -->
  <rect width="{WIDTH}" height="32" rx="8" fill="{C['surface0']}"/>
  <rect x="0" y="16" width="{WIDTH}" height="16" fill="{C['surface0']}"/>
  <circle cx="16" cy="16" r="6" fill="{C['red']}"/>
  <circle cx="34" cy="16" r="6" fill="{C['yellow']}"/>
  <circle cx="52" cy="16" r="6" fill="{C['green']}"/>
  <text x="{WIDTH // 2}" y="21" text-anchor="middle" font-family={FONT!r} font-size="13" fill="{C['subtext']}">{title}</text>
  <style>text {{ font-family: {FONT}; font-size: 13px; }}</style>
"""


def tspan(x: int, y: int, text: str, color: str) -> str:
    from html import escape
    return f'  <text x="{x}" y="{y}" fill="{color}">{escape(text)}</text>'


def line(row: int, parts: list[tuple[str, str]]) -> str:
    """Render a line from (text, color) parts."""
    y = PAD_Y + row * LINE_H
    pieces = []
    x = PAD_X
    for txt, col in parts:
        pieces.append(tspan(x, y, txt, col))
        x += len(txt) * CHAR_W
    return "\n".join(pieces)


def svg_footer() -> str:
    return "</svg>\n"


def write_svg(name: str, title: str, lines_data: list[list[tuple[str, str]]]):
    content = svg_header(title)
    for i, parts in enumerate(lines_data):
        content += line(i, parts) + "\n"
    content += svg_footer()
    path = os.path.join(SCRIPT_DIR, f"{name}.svg")
    with open(path, "w") as f:
        f.write(content)
    print(f"  Created {path}")


def gen_prompt():
    write_svg("prompt", "fish - ~/Projects/dotfiles", [
        [("~/Projects/dotfiles", C["blue"]), (" on ", C["subtext"]),
         (" main", C["green"]), (" [!]", C["yellow"])],
        [("❯ ", C["mauve"]), ("git status", C["text"])],
        [("On branch ", C["text"]), ("main", C["green"])],
        [("Your branch is up to date with ", C["text"]),
         ("'origin/main'", C["green"]), (".", C["text"])],
        [],
        [("Changes not staged for commit:", C["text"])],
        [("  modified:   ", C["text"]), ("dot_config/starship.toml", C["yellow"])],
        [("  modified:   ", C["text"]), ("dot_config/fish/config.fish", C["yellow"])],
        [],
        [("Untracked files:", C["text"])],
        [("  ", C["text"]), ("screenshots/", C["blue"])],
        [],
        [("~/Projects/dotfiles", C["blue"]), (" on ", C["subtext"]),
         (" main", C["green"]), (" [!?]", C["yellow"])],
        [("❯ ", C["mauve"]), ("█", C["text"])],
    ])


def gen_eza():
    write_svg("eza", "eza --tree", [
        [("~/Projects/dotfiles", C["blue"]), (" on ", C["subtext"]),
         (" main", C["green"])],
        [("❯ ", C["mauve"]), ("eza --tree --level=2 --icons", C["text"])],
        [(" .", C["blue"])],
        [("├── ", C["subtext"]), ("  dot_config/", C["blue"])],
        [("│   ├── ", C["subtext"]), ("  fish/", C["blue"])],
        [("│   ├── ", C["subtext"]), ("  starship.toml", C["green"])],
        [("│   ├── ", C["subtext"]), ("  atuin/", C["blue"])],
        [("│   └── ", C["subtext"]), ("  bat/", C["blue"])],
        [("├── ", C["subtext"]), ("  install/", C["blue"])],
        [("│   ├── ", C["subtext"]), ("  brew.sh", C["green"])],
        [("│   ├── ", C["subtext"]), ("  fish.sh", C["green"])],
        [("│   └── ", C["subtext"]), ("  link.sh", C["green"])],
        [("├── ", C["subtext"]), ("  bootstrap.sh", C["green"])],
        [("├── ", C["subtext"]), ("  Brewfile", C["text"])],
        [("├── ", C["subtext"]), ("  Makefile", C["text"])],
        [("└── ", C["subtext"]), ("  README.md", C["text"])],
    ])


def gen_bat():
    write_svg("bat", "bat - starship.toml", [
        [("❯ ", C["mauve"]), ("bat dot_config/starship.toml", C["text"])],
        [("───────┬────────────────────────────────────────", C["surface1"])],
        [("       │ ", C["surface1"]), ("File: ", C["subtext"]),
         ("dot_config/starship.toml", C["text"])],
        [("───────┼────────────────────────────────────────", C["surface1"])],
        [("   1   │ ", C["surface1"]), ("[character]", C["blue"])],
        [("   2   │ ", C["surface1"]), ("success_symbol", C["teal"]),
         (" = ", C["text"]), ('"[❯](green)"', C["green"])],
        [("   3   │ ", C["surface1"]), ("error_symbol", C["teal"]),
         (" = ", C["text"]), ('"[❯](red)"', C["green"])],
        [("   4   │ ", C["surface1"])],
        [("   5   │ ", C["surface1"]), ("[git_branch]", C["blue"])],
        [("   6   │ ", C["surface1"]), ("symbol", C["teal"]),
         (" = ", C["text"]), ('" "', C["green"])],
        [("   7   │ ", C["surface1"])],
        [("   8   │ ", C["surface1"]), ("[directory]", C["blue"])],
        [("   9   │ ", C["surface1"]), ("truncation_length", C["teal"]),
         (" = ", C["text"]), ("3", C["peach"])],
        [("  10   │ ", C["surface1"]), ("# ", C["subtext"]),
         ("Fish-compatible path truncation", C["subtext"])],
        [("───────┴────────────────────────────────────────", C["surface1"])],
    ])


def gen_fzf():
    write_svg("fzf", "fzf - fuzzy finder", [
        [("❯ ", C["mauve"]), ("ls | fzf", C["text"])],
        [("  ", C["text"]), ("6/14", C["yellow"]),
         (" ──────────────────────────────────", C["surface1"])],
        [("  ", C["text"]), ("Brewfile", C["text"])],
        [("  ", C["text"]), ("Makefile", C["text"])],
        [("  ", C["text"]), ("bootstrap.sh", C["green"])],
        [("  ", C["text"]), ("README.md", C["text"])],
        [("  ", C["text"]), ("LICENSE", C["text"])],
        [("> ", C["mauve"]), (".gitignore", C["teal"])],
        [],
        [("  ", C["text"]), ("> ", C["mauve"]), ("git", C["red"]),
         ("█", C["text"])],
    ])


def gen_atuin():
    write_svg("atuin", "atuin - shell history search", [
        [("❯ ", C["mauve"]), ("atuin search git", C["text"])],
        [],
        [(" 2024-12-15 10:23  ", C["subtext"]),
         ("git", C["red"]), (" push origin main", C["text"])],
        [(" 2024-12-15 09:45  ", C["subtext"]),
         ("git", C["red"]), (" commit -m 'feat: add starship config'", C["text"])],
        [(" 2024-12-14 16:30  ", C["subtext"]),
         ("git", C["red"]), (" add -A", C["text"])],
        [(" 2024-12-14 16:28  ", C["subtext"]),
         ("git", C["red"]), (" status", C["text"])],
        [(" 2024-12-14 14:12  ", C["subtext"]),
         ("git", C["red"]), (" clone https://github.com/user/dotfiles", C["text"])],
        [(" 2024-12-13 11:05  ", C["subtext"]),
         ("git", C["red"]), (" log --oneline -10", C["text"])],
        [(" 2024-12-13 09:22  ", C["subtext"]),
         ("git", C["red"]), (" diff HEAD~1", C["text"])],
        [],
        [(" [Enter] execute  [Tab] edit  [Esc] quit", C["subtext"])],
    ])


def gen_zoxide():
    write_svg("zoxide", "zoxide - smart cd", [
        [("❯ ", C["mauve"]), ("z dot", C["text"])],
        [("~/Projects/", C["subtext"]), ("dotfiles", C["blue"])],
        [],
        [("❯ ", C["mauve"]), ("zi", C["text"])],
        [(" score  │ path", C["subtext"])],
        [("────────┼──────────────────────────────", C["surface1"])],
        [("  120.5 │ ", C["subtext"]),
         ("/home/dev/Projects/dotfiles", C["blue"])],
        [("   85.2 │ ", C["subtext"]),
         ("/home/dev/Projects/dotfiles/dot_config", C["blue"])],
        [("   42.0 │ ", C["subtext"]),
         ("/home/dev/.config", C["blue"])],
        [("   18.7 │ ", C["subtext"]),
         ("/home/dev/Documents", C["blue"])],
    ])


def gen_delta():
    write_svg("delta", "delta - git diff", [
        [("❯ ", C["mauve"]), ("git diff", C["text"])],
        [("── ", C["surface1"]), ("dot_config/starship.toml", C["blue"]),
         (" ──────────────────────────", C["surface1"])],
        [],
        [("  [character]", C["subtext"])],
        [("- ", C["red"]), ('success_symbol = "[→](bold green)"', C["red"])],
        [("+ ", C["green"]), ('success_symbol = "[❯](green)"', C["green"])],
        [("  ", C["text"]), ('error_symbol = "[❯](red)"', C["subtext"])],
        [],
        [("  [directory]", C["subtext"])],
        [("- ", C["red"]), ("truncation_length = 5", C["red"])],
        [("+ ", C["green"]), ("truncation_length = 3", C["green"])],
        [("+ ", C["green"]), ("fish_style_pwd_dir_length = 1", C["green"])],
    ])


if __name__ == "__main__":
    print("Generating SVG screenshots...")
    gen_prompt()
    gen_eza()
    gen_bat()
    gen_fzf()
    gen_atuin()
    gen_zoxide()
    gen_delta()
    print("Done! Generated 7 SVG screenshots.")
