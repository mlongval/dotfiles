-- Hand-built statusline. See dotfiles/STATUSLINES.md for design notes.
--
-- Add or remove segments by editing M.segments below: `enabled = false`
-- hides a segment, `order` decides position. Empty render() output is
-- dropped so separators never collide.

local M = {}

local SEP = ' · '

-- Catppuccin-mocha palette
local C = {
  base     = '#1e1e2e',
  surface0 = '#313244',
  text     = '#cdd6f4',
  subtext  = '#a6adc8',
  red      = '#f38ba8',
  green    = '#a6e3a1',
  yellow   = '#f9e2af',
  blue     = '#89b4fa',
  mauve    = '#cba6f7',
  peach    = '#fab387',
}

-- Highlight groups. Defined once at setup() and re-applied on ColorScheme.
local HL = {
  StlBase = { fg = C.text,    bg = C.surface0, bold = false },
  StlDim  = { fg = C.subtext, bg = C.surface0 },
  StlMod  = { fg = C.peach,   bg = C.surface0, bold = true },
  StlErr  = { fg = C.red,     bg = C.surface0, bold = true },
  StlWarn = { fg = C.yellow,  bg = C.surface0 },
  StlModeN = { fg = C.base, bg = C.blue,  bold = true },
  StlModeI = { fg = C.base, bg = C.green, bold = true },
  StlModeV = { fg = C.base, bg = C.mauve, bold = true },
  StlModeR = { fg = C.base, bg = C.peach, bold = true },
  StlModeC = { fg = C.base, bg = C.yellow,bold = true },
  StlModeT = { fg = C.base, bg = C.red,   bold = true },
}

local function apply_highlights()
  for name, spec in pairs(HL) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  -- Statusline backgrounds (active + inactive)
  vim.api.nvim_set_hl(0, 'StatusLine',   { fg = C.text,    bg = C.surface0 })
  vim.api.nvim_set_hl(0, 'StatusLineNC', { fg = C.subtext, bg = C.base })
end

-- Wrap a string in a highlight group for the statusline.
local function hl(group, s)
  if not s or s == '' then return '' end
  return '%#' .. group .. '#' .. s
end

-- ---------------------------------------------------------------------
-- Segments
-- ---------------------------------------------------------------------

local MODE_MAP = {
  n  = { 'N', 'StlModeN' },
  no = { 'N', 'StlModeN' },
  i  = { 'I', 'StlModeI' },
  ic = { 'I', 'StlModeI' },
  v  = { 'V', 'StlModeV' },
  V  = { 'V', 'StlModeV' },
  [''] = { 'V', 'StlModeV' },  -- visual block (C-v)
  s  = { 'S', 'StlModeV' },
  R  = { 'R', 'StlModeR' },
  c  = { 'C', 'StlModeC' },
  t  = { 'T', 'StlModeT' },
}

local function seg_mode()
  local m = vim.api.nvim_get_mode().mode
  local entry = MODE_MAP[m] or MODE_MAP[m:sub(1,1)] or { '?', 'StlBase' }
  return hl(entry[2], ' ' .. entry[1] .. ' ')
end

local function seg_file()
  local name = vim.fn.expand('%:t')
  if name == '' then name = '[No Name]' end
  local flags = ''
  if vim.bo.modified  then flags = flags .. '+' end
  if vim.bo.readonly  then flags = flags .. '!' end
  return hl('StlBase', name) .. (flags ~= '' and hl('StlMod', flags) or '')
end

local function seg_align()
  return '%='
end

-- Only show filetype when it adds information the extension doesn't.
-- Extensions like .lua/.vim/.md make filetype redundant; clinote (no
-- extension) and a few others are worth surfacing.
local FT_SHOW = { clinote = true, vimwiki = true, help = true, gitcommit = true }

local function seg_filetype()
  local ft = vim.bo.filetype
  if ft == '' or not FT_SHOW[ft] then return '' end
  return hl('StlDim', ft)
end

local function seg_diag()
  if not vim.diagnostic then return '' end
  local d = vim.diagnostic.count and vim.diagnostic.count(0) or {}
  local e = d[vim.diagnostic.severity.ERROR] or 0
  local w = d[vim.diagnostic.severity.WARN]  or 0
  if e == 0 and w == 0 then return '' end
  local parts = {}
  if e > 0 then table.insert(parts, hl('StlErr',  'E:' .. e)) end
  if w > 0 then table.insert(parts, hl('StlWarn', 'W:' .. w)) end
  return table.concat(parts, ' ')
end

local function seg_pos()
  return hl('StlDim', '%l:%c')
end

-- ---------------------------------------------------------------------
-- Segment table — edit this to add / remove / reorder / hide
-- ---------------------------------------------------------------------

M.segments = {
  { id = 'mode',     enabled = true,  order = 10, render = seg_mode,     right = false },
  { id = 'file',     enabled = true,  order = 20, render = seg_file,     right = false },
  { id = 'align',    enabled = true,  order = 50, render = seg_align,    right = false },
  { id = 'filetype', enabled = true,  order = 60, render = seg_filetype, right = true  },
  { id = 'diag',     enabled = true,  order = 70, render = seg_diag,     right = true  },
  { id = 'pos',      enabled = true,  order = 90, render = seg_pos,      right = true  },
}

-- ---------------------------------------------------------------------
-- Assembly
-- ---------------------------------------------------------------------

-- Build is called by %!v:lua.require'statusline'.build() on every redraw.
-- Keep it cheap: no shellouts, no globbing.
function M.build()
  -- Sort once per build. The table is tiny; cost is negligible.
  local segs = {}
  for _, s in ipairs(M.segments) do
    if s.enabled then table.insert(segs, s) end
  end
  table.sort(segs, function(a, b) return a.order < b.order end)

  local left, right = {}, {}
  local seen_align = false
  for _, s in ipairs(segs) do
    if s.id == 'align' then
      seen_align = true
      table.insert(left, '%=')
    else
      local out = s.render()
      if out and out ~= '' then
        if seen_align then table.insert(right, out)
        else               table.insert(left,  out) end
      end
    end
  end

  local function join(t) return table.concat(t, hl('StlBase', SEP)) end
  -- Pad both ends so first/last segments don't touch the screen edge.
  local sep_hl = hl('StlBase', ' ')
  return sep_hl .. join(left) .. (seen_align and '' or ' ') .. join(right) .. sep_hl
end

-- ---------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------

function M.setup()
  apply_highlights()
  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = apply_highlights,
    desc = 'Reapply statusline highlights after :colorscheme',
  })
  vim.o.laststatus  = 2
  vim.o.statusline  = "%!v:lua.require'statusline'.build()"
end

return M
