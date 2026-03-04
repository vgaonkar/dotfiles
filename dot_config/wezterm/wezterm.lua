-- WezTerm configuration
-- Translated from Windows Terminal settings (JetBrainsMono, Tango Dark, 50% opacity, acrylic)
-- https://wezfurlong.org/wezterm/config/files.html

local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action
local target = wezterm.target_triple

-- ── Font ──────────────────────────────────────────────────────────────────────
config.font = wezterm.font('JetBrainsMono Nerd Font Mono')
config.font_size = 12.0

-- ── Colors (Tango Dark) ───────────────────────────────────────────────────────
config.colors = {
  foreground    = '#eeeeec',
  background    = '#000000',
  cursor_bg     = '#eeeeec',
  cursor_fg     = '#000000',
  cursor_border = '#eeeeec',
  selection_fg  = '#000000',
  selection_bg  = '#eeeeec',
  ansi = {
    '#000000', -- black
    '#cc0000', -- red
    '#4e9a06', -- green
    '#c4a000', -- yellow
    '#3465a4', -- blue
    '#75507b', -- magenta
    '#06989a', -- cyan
    '#d3d7cf', -- white
  },
  brights = {
    '#555753', -- bright black
    '#ef2929', -- bright red
    '#8ae234', -- bright green
    '#fce94f', -- bright yellow
    '#729fcf', -- bright blue
    '#ad7fa8', -- bright magenta
    '#34e2e2', -- bright cyan
    '#eeeeec', -- bright white
  },
}

-- ── Transparency & blur ───────────────────────────────────────────────────────
-- 50% opacity, matching Windows Terminal "opacity": 50 + "useAcrylic": true
config.window_background_opacity = 0.5
if target:find('windows') then
  config.win32_system_backdrop = 'Acrylic'
elseif target:find('apple') then
  config.macos_window_background_blur = 20
end

-- ── Default shell / domain ────────────────────────────────────────────────────
-- On Windows: open WSL Ubuntu and land in ~/Projects (matching WT Ubuntu profile)
if target:find('windows') then
  config.default_domain = 'WSL:Ubuntu'
end
config.default_cwd = '~/Projects'

-- ── Window chrome ─────────────────────────────────────────────────────────────
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar           = false
config.window_decorations          = 'TITLE | RESIZE'
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }

-- ── Keybindings (matching Windows Terminal) ───────────────────────────────────
-- ctrl+c  → Copy  (same as WT; use ctrl+shift+c to send interrupt signal)
-- ctrl+v  → Paste
-- ctrl+shift+f → Search
-- alt+shift+d  → Split pane (duplicate, right)
config.keys = {
  {
    key   = 'f',
    mods  = 'CTRL|SHIFT',
    action = act.Search { CaseSensitiveString = '' },
  },
  {
    key    = 'c',
    mods   = 'CTRL',
    action = act.CopyTo 'Clipboard',
  },
  {
    -- Send actual interrupt (ETX 0x03) when you need to cancel a process
    key    = 'c',
    mods   = 'CTRL|SHIFT',
    action = act.SendString '\x03',
  },
  {
    key    = 'v',
    mods   = 'CTRL',
    action = act.PasteFrom 'Clipboard',
  },
  {
    key   = 'd',
    mods  = 'ALT|SHIFT',
    action = act.SplitPane {
      direction = 'Right',
      command   = { domain = 'CurrentPaneDomain' },
    },
  },
}

return config
