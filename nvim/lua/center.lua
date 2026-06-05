-- center.lua: center the text column on screen by flanking the current
-- window with a blank "padding" window on the left.
--
-- Used by the <leader>n cycle (mode 2). Neovim caps foldcolumn/signcolumn
-- at 9 each, so a gutter can't push a 56-column note to the middle of a
-- wide terminal. A scratch side-window can, at any width.
--
-- Only a *left* pad is needed: the note wraps at textwidth (56), so the
-- note window's own empty right half is the right margin — a right pad
-- would just duplicate it. The left pad's width is chosen so the wrapped
-- text sits centered. The pad is torn down when the cycle leaves mode 2
-- (see CycleNumberMode in init.vim) and resized on VimResized.

local M = {}

-- state.left holds the pad window id while centering is on.
local state = { left = nil }

local function is_win(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w)
end

-- Desired text-column width: the buffer's textwidth, else 56 (clinical default).
local function text_width()
  local tw = vim.bo.textwidth
  if tw and tw > 0 then return tw end
  return 56
end

-- A blank, throwaway buffer for a pad window.
local function make_pad_buf()
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].buftype   = 'nofile'
  vim.bo[b].bufhidden = 'wipe'
  vim.bo[b].swapfile  = false
  vim.bo[b].buflisted = false
  return b
end

-- Strip every gutter/decoration so a pad reads as empty margin.
local function style_pad(win)
  local wo = vim.wo[win]
  wo.number         = false
  wo.relativenumber = false
  wo.foldcolumn     = '0'
  wo.signcolumn     = 'no'
  wo.colorcolumn    = ''
  wo.cursorline     = false
  wo.cursorcolumn   = false
  wo.list           = false
  wo.winfixwidth    = true
  -- eob: hides the ~ end-of-buffer markers. vert: must be re-set here too:
  -- a per-window fillchars replaces the global value wholesale, so without
  -- it the pad's separator edge reverts to the default '│' glyph (the line
  -- between the pad and the note). Keep it blank.
  wo.fillchars      = 'eob: ,vert: '
  wo.statusline     = ' '       -- blank statusline in the margin
end

function M.is_active()
  return is_win(state.left)
end

-- Close the pad (idempotent). state is cleared *before* closing so the
-- WinClosed autocmd below doesn't recurse.
function M.off()
  local l = state.left
  state.left = nil
  if is_win(l) then pcall(vim.api.nvim_win_close, l, true) end
end

-- Width for the left pad. The left margin is the pad plus the one vertical
-- separator the split introduces, so pad = floor((cols - text)/2) - 1; the
-- note window then keeps the rest, with its wrapped text flush left and its
-- empty right half forming the (matching) right margin. nil if too narrow.
local function pad_width()
  local left = math.floor((vim.o.columns - text_width()) / 2) - 1
  if left < 1 then return nil end
  return left
end

-- Turn centering on, or re-fit the pad if already on (VimResized path).
function M.on()
  local left_w = pad_width()
  if not left_w then
    M.off()   -- screen too narrow to center; just let the text fill it
    return
  end

  if M.is_active() then
    if is_win(state.left) then vim.api.nvim_win_set_width(state.left, left_w) end
    return
  end

  -- Fresh activation needs a lone text window; bail (no pad) if the user
  -- already has splits open, rather than mangle their layout.
  if #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.notify('[,n] Close other splits to center the note.', vim.log.levels.WARN)
    return
  end

  local text_win = vim.api.nvim_get_current_win()

  vim.cmd('topleft vsplit')
  local left = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(left, make_pad_buf())
  style_pad(left)
  state.left = left

  vim.api.nvim_win_set_width(left, left_w)
  vim.api.nvim_set_current_win(text_win)
end

-- Autocmds: keep the pad fitted on resize, and tidy state if the pad is
-- closed out from under us.
local aug = vim.api.nvim_create_augroup('ClinicalCenter', { clear = true })
vim.api.nvim_create_autocmd('VimResized', {
  group = aug,
  callback = function() if M.is_active() then M.on() end end,
})
vim.api.nvim_create_autocmd('WinClosed', {
  group = aug,
  callback = function(ev)
    local w = tonumber(ev.match)
    if w == state.left then
      vim.schedule(function() M.off() end)
    end
  end,
})
-- Single :q on the note exits nvim while centered. Without this, quitting
-- the note window leaves the pad behind, needing a second :q. When the
-- window being quit is the note (not the pad), tear the pad down first so
-- the pending :q lands on the last window and exits cleanly.
vim.api.nvim_create_autocmd('QuitPre', {
  group = aug,
  callback = function()
    if not M.is_active() then return end
    if vim.api.nvim_get_current_win() ~= state.left then
      M.off()
    end
  end,
})

return M
