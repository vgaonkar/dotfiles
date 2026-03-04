-- WezTerm configuration — performance-optimised
-- https://wezfurlong.org/wezterm/config/files.html

local wezterm = require 'wezterm'
local config  = wezterm.config_builder()
local act     = wezterm.action
local target  = wezterm.target_triple

-- ── GPU / Renderer ────────────────────────────────────────────────────────────
-- WebGPU is the fastest front-end; auto-falls-back to OpenGL if unavailable.
config.front_end               = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'
-- 120 fps cap — smooth scrolling without burning GPU at idle
config.max_fps        = 120
config.animation_fps  = 60

-- ── Font ──────────────────────────────────────────────────────────────────────
config.font      = wezterm.font('JetBrainsMono Nerd Font Mono')
config.font_size = 12.0
-- Light hinting + LCD sub-pixel rendering — crisp on modern monitors
config.freetype_load_target  = 'Light'
config.freetype_render_target = 'HorizontalLcd'

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
-- Raised opacity 0.5 → 0.85: less compositing work, still translucent.
-- On Windows: Mica uses DWM hardware composition (much faster than Acrylic
-- software blur).  Acrylic is beautiful but costs ~10 ms/frame in WezTerm.
config.window_background_opacity = 0.85
if target:find('windows') then
  config.win32_system_backdrop = 'Mica'
elseif target:find('apple') then
  config.macos_window_background_blur = 20
end

-- ── Cursor ────────────────────────────────────────────────────────────────────
-- Steady block = zero per-frame redraws from blink animation
config.default_cursor_style = 'SteadyBlock'
config.cursor_blink_rate    = 0

-- ── Scrollback ────────────────────────────────────────────────────────────────
config.scrollback_lines = 10000

-- ── Default shell / domain ────────────────────────────────────────────────────
if target:find('windows') then
  config.default_domain = 'WSL:Ubuntu'
end
config.default_cwd = '~/Projects'

-- ── Window chrome ─────────────────────────────────────────────────────────────
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar            = false
config.window_decorations           = 'TITLE | RESIZE'
config.window_padding               = { left = 4, right = 4, top = 4, bottom = 4 }
config.enable_scroll_bar            = false

-- ── Misc performance tweaks ───────────────────────────────────────────────────
-- Avoid a background network call on launch
config.check_for_updates = false
-- Audible bell is a tiny cost; visual flash is cheaper than a system beep
config.audible_bell = 'Disabled'

-- ── Keybindings (matching Windows Terminal) ───────────────────────────────────
-- ctrl+c          → Copy
-- ctrl+shift+c    → Send interrupt (ETX 0x03)
-- ctrl+v          → Paste
-- ctrl+shift+f    → Search
-- alt+shift+d     → Split pane right
config.keys = {
  {
    key    = 'f',
    mods   = 'CTRL|SHIFT',
    action = act.Search { CaseSensitiveString = '' },
  },
  {
    key    = 'c',
    mods   = 'CTRL',
    action = act.CopyTo 'Clipboard',
  },
  {
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
    key    = 'd',
    mods   = 'ALT|SHIFT',
    action = act.SplitPane {
      direction = 'Right',
      command   = { domain = 'CurrentPaneDomain' },
    },
  },
}

return config
