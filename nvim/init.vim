" ============================================================
" Regular nvim — generic editor config.
"
" Clinical-note editing lives in a SEPARATE config under
" ~/.config/clinical-nvim → ~/Projects/ClinicalNotesSystem/neovim/config.
" Do not add clinical workflow, snippets, or lua modules here.
" ============================================================

" ============================================================
" Python provider (pynvim via uv)
" ============================================================
let s:uv_python = expand('~/.local/share/uv/tools/pynvim/bin/python3')
if executable(s:uv_python)
  let g:python3_host_prog = s:uv_python
endif

" ============================================================
" Bootstrap vim-plug
" ============================================================
let s:plug_vim = expand('~/.vim/autoload/plug.vim')
if empty(glob(s:plug_vim))
  silent execute '!curl -fLo ' . s:plug_vim . ' --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

if has('nvim')
  let s:nvim_autoload = stdpath('data') . '/site/autoload/plug.vim'
  if empty(glob(s:nvim_autoload))
    silent execute '!mkdir -p ' . fnamemodify(s:nvim_autoload, ':h') . ' && ln -sf ' . s:plug_vim . ' ' . s:nvim_autoload
  endif
endif

" ============================================================
" Plugins
" ============================================================
" XDG-correct plug_home: ~/.local/share/nvim/plugged (or
" ~/.local/share/<appname>/plugged when NVIM_APPNAME is set).
call plug#begin(stdpath('data') . '/plugged')

" Writing / Focus
Plug 'vimwiki/vimwiki'
Plug 'https://github.com/preservim/vim-pencil'
Plug 'junegunn/goyo.vim'
Plug 'https://codeberg.org/turysaz/vim-zenmode'

" Navigation
Plug 'easymotion/vim-easymotion'
Plug 'preservim/nerdtree'

" UI
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'
Plug 'yggdroot/indentline'
Plug 'catppuccin/vim', { 'as': 'catppuccin' }

" Editing
Plug 'ntpeters/vim-better-whitespace'
Plug 'https://github.com/pseewald/vim-anyfold'
Plug 'bullets-vim/bullets.vim'

" Prettification
Plug 'stevearc/dressing.nvim'

" Browser text fields — edit in nvim via firenvim extension
Plug 'glacambre/firenvim', { 'do': { -> firenvim#install(0) } }

" Key hints popup (neovim only)
if has('nvim')
  Plug 'folke/which-key.nvim'
endif
call plug#end()

" ============================================================
" General settings
" ============================================================
let s:very_dark_gray = 234
let s:darker_gray    = 236
let s:medium_gray    = 240
let s:light_gray     = 244

set tabstop=4
set softtabstop=0
set expandtab
set shiftwidth=4
set smarttab
set autoindent
set smartcase
set ignorecase
set backspace=indent,eol,start
set helplang=en
set laststatus=2
set nomodeline
set ruler
set textwidth=56
set number
set relativenumber
set foldmethod=indent
set foldlevel=99
set colorcolumn=56
set spell
set spelllang=fr
execute 'set spellfile=' . stdpath('config') . '/spell/fr.utf-8.add'
" Disable spell for ephemeral buffers (e.g. Claude Code ctrl-g scratch files)
" — undercurl/underline attrs can leak back into the host TUI on exit.
augroup NoSpellTmp
  autocmd!
  autocmd BufRead,BufNewFile /tmp/*,/var/tmp/*,/dev/shm/* setlocal nospell
augroup END
" Textern (browser textbox → nvim) writes under $XDG_RUNTIME_DIR/textern/textern-*/
" (or /tmp/textern-*/ fallback). Force English spell + English word list there for
" Claude prompts. Must come after NoSpellTmp to override its nospell on the /tmp path.
augroup TexternEnSpell
  autocmd!
  autocmd BufRead,BufNewFile */textern-*/* execute 'setlocal spell spelllang=en spellfile=' . stdpath('config') . '/spell/en.utf-8.add'
augroup END
set showtabline=0
set fillchars+=vert:\ ,diff:-
set numberwidth=4
set scrolloff=999
set linebreak
set noswapfile
set updatetime=60000

execute 'highlight ColorColumn'  . ' ctermbg=' . s:darker_gray
highlight SpellBad   ctermfg=NONE ctermbg=NONE cterm=underline gui=underline
highlight SpellCap   cterm=underline gui=underline
highlight SpellLocal cterm=underline gui=underline
highlight SpellRare  cterm=underline gui=underline

if !has('nvim')
  set printfont=courier:h14
  set printoptions=paper:letter
endif

" ============================================================
" Plugin settings
" ============================================================

" Airline
let g:airline_left_sep  = ''
let g:airline_right_sep = ''

" Anyfold
let g:anyfold_fold_comments = 0

" Vimwiki
if hostname() == 'ubuntu-s1'
  let g:vimwiki_list = [{'path': '~/Documents/vimwiki/', 'syntax': 'markdown', 'ext': '.md'}]
else
  let g:vimwiki_list = [{'path': '~/vimwiki/', 'syntax': 'markdown', 'ext': '.md'}]
endif

" Bullets — list continuation on <CR> for these filetypes
let g:bullets_enabled_file_types = ['markdown', 'text', 'gitcommit', 'scratch']
let g:bullets_enable_in_empty_buffers = 0
let g:bullets_set_mappings = 1
let g:bullets_pad_right = 0

" ============================================================
" Key mappings
" ============================================================
let mapleader = ','

" EasyMotion
nmap <leader><leader> <Plug>(easymotion-prefix)
xmap <leader><leader> <Plug>(easymotion-prefix)
omap <leader><leader> <Plug>(easymotion-prefix)
map  f                <leader><leader>

" Escape / whitespace
imap jk <ESC>:StripWhitespace<CR><ESC>
map  <leader>s :StripWhitespace<CR>

" Clipboard (Wayland)
vmap <leader>y "+y
map  <leader>Y <esc>ggvGg_"+y
map  <leader>p "+p
vmap <C-c> "+yi
vmap <C-x> "+c
vmap <C-v> c<ESC>"+p
imap <C-v> <ESC>"+pa

" Tabs
map <leader>T :tabnew<CR>
map <leader>t :tabnext<CR>

" System / battery
map  <leader>b :!clear;acpi<CR>

" Calendar / focus modes
map  <leader>q :!clear;cal -3; cat ~/Documents/CANADA_HOLIDAYS.txt;<CR>
map  <leader>g <ESC>:Goyo<CR>

function! s:goyo_enter()
  let b:goyo_quitting = 0
  autocmd QuitPre <buffer> let b:goyo_quitting = 1
endfunction

function! s:goyo_leave()
  if b:goyo_quitting
    wq
  endif
endfunction

autocmd! User GoyoEnter nested call <SID>goyo_enter()
autocmd! User GoyoLeave nested call <SID>goyo_leave()
map  <leader>z <ESC>:ZEN<CR>

" Misc
map      <leader>n   <ESC>:set number relativenumber<CR>
nnoremap <leader>nw  :set numberwidth=12<CR>
nnoremap <BS>        :call ExitAtBufferStart()<CR>
nnoremap <Tab>       :call EndOfLineTab()<CR>
nmap     <F2>        :ZEN<CR>
nmap     <F7>        :set spell!<CR>
nmap     zf          [s1z=$
imap     zf          <esc>[s1z=$a
nmap     gF          <leader>bb<c-^><cr>

" Disable q (use Q for macros if needed)
nnoremap q <Nop>
vnoremap q <Nop>

" h exits when at top-left of an unmodified buffer
nnoremap <expr> h (line('.') == 1 && col('.') == 1 && !&modified) ? ':quit<CR>' : 'h'

" ============================================================
" Cursor shape per mode
" ============================================================
let &t_SI .= "\e[5 q"
let &t_SR .= "\e[4 q"
let &t_EI .= "\e[1 q"

" ============================================================
" External files
" ============================================================
execute 'source ' . stdpath('config') . '/functions.vim'

" ============================================================
" Neovim-only
" ============================================================
if has('nvim')
  " OSC 52 clipboard — works over SSH/tmux without display server
  set clipboard=unnamedplus
  if has('nvim-0.10')
    lua << EOF
    vim.g.clipboard = {
      name = 'OSC 52',
      copy = {
        ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
        ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
      },
      paste = {
        ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
        ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
      },
    }
EOF
  endif

  " dressing.nvim — prettier vim.ui.select and vim.ui.input
  lua require('dressing').setup({})

  " which-key — leader hint popup (only if installed)
  lua << EOF
  local ok, wk = pcall(require, 'which-key')
  if ok then
    wk.setup({ delay = 400 })
    wk.add({
      { '<leader>y',  desc = 'Copier sélection → presse-papier', mode = 'v' },
      { '<leader>Y',  desc = 'Copier tout le tampon → presse-papier' },
      { '<leader>p',  desc = 'Coller depuis presse-papier' },
      { '<leader>s',  desc = 'Supprimer les espaces superflus' },
      { '<leader>g',  desc = 'Goyo — mode focus' },
      { '<leader>z',  desc = 'ZEN mode' },
      { '<leader>q',  desc = 'Calendrier + jours fériés' },
      { '<leader>b',  desc = 'Batterie (acpi)' },
      { '<leader>n',  desc = 'Afficher les numéros de ligne' },
      { '<leader>w',  group = 'VimWiki' },
      { '<leader>t',  group = 'Onglets' },
    })
  end
EOF

  " VimWiki cheatsheet popup
  function! s:VimwikiHelp() abort
    let lines = [
      \ '  VimWiki Cheatsheet  (leader = ,)       ',
      \ ' ─────────────────────────────────────── ',
      \ '  Navigation                              ',
      \ '   ,ww       Open index                  ',
      \ '   ,wd       Open diary index             ',
      \ '   ,w,w      Today''s diary entry          ',
      \ '   <Enter>   Follow / create link         ',
      \ '   <BS>      Go back                      ',
      \ '   <Tab>     Next link on page            ',
      \ '   <S-Tab>   Previous link on page        ',
      \ ' ─────────────────────────────────────── ',
      \ '  Editing                                 ',
      \ '   ,wn       New wiki page                ',
      \ '   =         Increase heading level       ',
      \ '   -         Decrease heading level       ',
      \ ' ─────────────────────────────────────── ',
      \ '  Diary                                   ',
      \ '   ,w,w      Today                        ',
      \ '   ,w,t      Today in new tab             ',
      \ '   ,w,y      Yesterday                    ',
      \ '   ,w,m      Tomorrow                     ',
      \ ' ─────────────────────────────────────── ',
      \ '  Lists (insert mode)                     ',
      \ '   <C-Space> Toggle checkbox [ ] → [X]   ',
      \ ' ─────────────────────────────────────── ',
      \ '   ,w?      This cheatsheet                 ',
      \ ' ─────────────────────────────────────── ',
      \ '        <Esc> / q / <Enter> to close      ',
      \ ]
    let width  = max(map(copy(lines), 'len(v:val)'))
    let height = len(lines)
    let row    = (&lines   - height) / 2
    let col    = (&columns - width)  / 2
    let buf = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_lines(buf, 0, -1, v:true, lines)
    call nvim_buf_set_option(buf, 'modifiable', v:false)
    call nvim_buf_set_option(buf, 'bufhidden',  'wipe')
    call nvim_open_win(buf, v:true, {
      \ 'relative': 'editor',
      \ 'width':    width,
      \ 'height':   height,
      \ 'row':      row,
      \ 'col':      col,
      \ 'style':    'minimal',
      \ 'border':   'rounded',
      \ })
    nnoremap <buffer> <Esc>   :close<CR>
    nnoremap <buffer> q       :close<CR>
    nnoremap <buffer> <CR>    :close<CR>
  endfunction
  nnoremap <leader>w? :call <SID>VimwikiHelp()<CR>
endif
