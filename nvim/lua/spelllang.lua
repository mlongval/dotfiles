-- spelllang.lua — `zl` popup to pick the spell-check language
-- for the current buffer: French, English, German, Spanish.
--
-- Picking a language sets, buffer-locally, spell + spelllang +
-- spellfile (spell/<code>.utf-8.add under stdpath('config')),
-- so `zg` adds words to that language's own list.
--
-- If a language's dictionary (<code>.utf-8.spl) isn't on the
-- runtimepath yet, it is downloaded once in the background,
-- with its .sug suggestion file, into
-- stdpath('data')/site/spell.
--
-- The same file lives in ClinicalNotesSystem/neovim/lua/ and
-- ~/dotfiles/nvim/lua/. Keep the two copies identical.

local M = {}

local LANGS = {
    { code = 'fr', name = 'French' },
    { code = 'en', name = 'English' },
    { code = 'de', name = 'German' },
    { code = 'es', name = 'Spanish' },
}

local MIRROR = 'https://ftp.nluug.nl/pub/vim/runtime/spell/'

local function have_dict(code)
    local f = 'spell/' .. code .. '.utf-8.spl'
    return #vim.api.nvim_get_runtime_file(f, false) > 0
end

-- Fetch <code>.utf-8.spl (required), then .sug (optional),
-- in the background: the mirror can be slow (minutes). Calls
-- on_done() on the main loop once the .spl is in place.
local function download(code, on_done)
    local dir = vim.fn.stdpath('data') .. '/site/spell'
    vim.fn.mkdir(dir, 'p')
    vim.notify('[spell] Downloading ' .. code
               .. ' dictionary (may take a few minutes)…')
    local function fetch(ext, next_step)
        local name = code .. '.utf-8.' .. ext
        local dest = dir .. '/' .. name
        local tmp  = dest .. '.part'
        vim.system({ 'curl', '-fsSL', '--retry', '3',
                     '--connect-timeout', '20', '-o', tmp,
                     MIRROR .. name }, {}, function(res)
            vim.schedule(function()
                if res.code == 0 then
                    os.rename(tmp, dest)
                else
                    os.remove(tmp)
                end
                next_step(res.code == 0)
            end)
        end)
    end
    fetch('spl', function(ok)
        if not ok then
            vim.notify('[spell] Download failed: ' .. code
                       .. '.utf-8.spl', vim.log.levels.ERROR)
            return
        end
        on_done()
        fetch('sug', function() end)
    end)
end

-- Apply to the buffer that was current when the user picked,
-- even if the download finished after they moved on.
local function apply(buf, code, name)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.api.nvim_buf_call(buf, function()
        vim.opt_local.spell     = true
        vim.opt_local.spelllang = code
        vim.opt_local.spellfile = vim.fn.stdpath('config')
                                  .. '/spell/' .. code .. '.utf-8.add'
    end)
    vim.notify('[spell] ' .. name)
end

function M.set(code, name)
    local buf = vim.api.nvim_get_current_buf()
    name = name or code
    if have_dict(code) then
        apply(buf, code, name)
    else
        download(code, function() apply(buf, code, name) end)
    end
end

function M.pick()
    local current = vim.bo.spelllang
    vim.ui.select(LANGS, {
        prompt = 'Spell language',
        format_item = function(l)
            local mark = (vim.wo.spell and l.code == current)
                         and '  ●' or ''
            return l.name .. mark
        end,
    }, function(choice)
        if not choice then return end
        M.set(choice.code, choice.name)
    end)
end

return M
