-- ~/.config/nvim/lua/patientnote.lua
--
-- Commands:
--   :NotePDF   — Save buffer, generate PDF, open it
--   :NotePrint — Save buffer, generate PDF, send to printer
--
-- Note file format (plain text, any extension):
--   PATIENT: Prénom Nom
--   RAMQ: XXXX 0000 0000
--   DATE: 13.04.2026
--   TEL: 819.555.0000
--   SIG: Dr Prénom Nom, MD
--   ---
--   Corps de la note...

local M = {}

local SCRIPT  = vim.fn.expand('~/bin/note2pdf')
local PRINTER = nil  -- nil = default; set to e.g. "hp_bureau" to force a queue

local function notify(msg, level)
  vim.notify('[NotePDF] ' .. msg, level or vim.log.levels.INFO)
end

local function run(cmd)
  local out = vim.fn.system(cmd)
  return out, vim.v.shell_error
end

local function export(open_after, print_after)
  vim.cmd('silent write')

  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == '' then
    notify('Buffer non sauvegardé (pas de chemin).', vim.log.levels.ERROR)
    return
  end

  local pdfpath = vim.fn.fnamemodify(bufpath, ':r') .. '.pdf'

  local cmd = SCRIPT
  if open_after then cmd = cmd .. ' --open' end
  cmd = cmd .. ' ' .. vim.fn.shellescape(bufpath)
         .. ' ' .. vim.fn.shellescape(pdfpath)

  notify('Génération du PDF en cours…')
  local out, err = run(cmd)

  if err ~= 0 then
    notify('Échec :\n' .. (out or ''), vim.log.levels.ERROR)
    return
  end

  notify(out:gsub('%s+$', ''))  -- trim trailing whitespace from script output

  if print_after then
    local lpr = 'lpr '
      .. (PRINTER and ('-P ' .. PRINTER .. ' ') or '')
      .. vim.fn.shellescape(pdfpath)
    local _, perr = run(lpr)
    if perr ~= 0 then
      notify('Impression échouée.', vim.log.levels.ERROR)
    else
      notify('Envoyé à l\'imprimante.')
    end
  end
end

function M.setup()
  vim.api.nvim_create_user_command('NotePDF', function()
    export(true, false)
  end, { desc = 'Note patient → PDF (ouvre après génération)' })

  vim.api.nvim_create_user_command('NotePrint', function()
    export(false, true)
  end, { desc = 'Note patient → PDF → imprimante par défaut' })
end

return M
