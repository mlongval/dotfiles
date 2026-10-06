" ============================================================
" ftplugin/markdown.vim — Markdown editing helpers
" (leader = ,)
"
"   ,S   toggle ~~strikethrough~~
"        normal mode : word under the cursor (or the ~~span~~
"                      the cursor sits inside — toggles off)
"        visual mode : the selection
"   ,N   open a new line below and start it with "NOTE: "
"   ,M   turn the CURRENT line into a "NOTE: " line (toggle)
"
" (,x is left alone — bullets.vim owns it for checkboxes.)
"
" nvim-surround also gives ysiw~ / S~ / ds~ / cs~* — see the
" surrounds table in init.vim. These maps are the fast path
" and work in plain vim too.
" ============================================================

if exists('b:loaded_md_helpers')
  finish
endif
let b:loaded_md_helpers = 1

" ------------------------------------------------------------
" Strikethrough
" ------------------------------------------------------------
function! s:StrikeNormal() abort
  let l:line = getline('.')
  let l:col  = col('.')
  let l:pat  = '\~\~.\{-}\~\~'

  " Cursor inside an existing ~~span~~ ? -> unwrap it.
  let l:from = 0
  while 1
    let l:s = match(l:line, l:pat, l:from)
    if l:s < 0
      break
    endif
    let l:e = matchend(l:line, l:pat, l:from)
    if l:col > l:s && l:col <= l:e
      let l:inner = strpart(l:line, l:s + 2, l:e - l:s - 4)
      call setline('.', strpart(l:line, 0, l:s) . l:inner . strpart(l:line, l:e))
      call cursor(line('.'), max([1, l:col - 2]))
      return
    endif
    let l:from = l:e
  endwhile

  " Otherwise wrap the word under the cursor.
  let l:w = expand('<cword>')
  if l:w ==# ''
    return
  endif
  execute "normal! ciw~~" . l:w . "~~"
endfunction

function! s:StrikeVisual() abort
  let l:save     = getreg('"')
  let l:savetype = getregtype('"')
  silent normal! gvy
  let l:txt = getreg('"')
  if l:txt =~# '^\~\~\_.*\~\~$'
    let l:new = substitute(l:txt, '^\~\~\(\_.*\)\~\~$', '\1', '')
  else
    let l:new = '~~' . l:txt . '~~'
  endif
  call setreg('"', l:new, 'v')
  silent normal! gvp
  call setreg('"', l:save, l:savetype)
endfunction

nnoremap <buffer> <silent> <leader>S :call <SID>StrikeNormal()<CR>
xnoremap <buffer> <silent> <leader>S :<C-u>call <SID>StrikeVisual()<CR>

" ------------------------------------------------------------
" NOTE: lines
" ------------------------------------------------------------
" New line below, prefilled, insert mode.
nnoremap <buffer> <leader>N oNOTE:<Space>

" Toggle the "NOTE: " prefix on the current line.
function! s:ToggleNote() abort
  let l:line = getline('.')
  if l:line =~# '^\s*NOTE:\s\?'
    call setline('.', substitute(l:line, '^\(\s*\)NOTE:\s\?', '\1', ''))
  else
    call setline('.', substitute(l:line, '^\(\s*\)', '\1NOTE: ', ''))
  endif
endfunction

nnoremap <buffer> <silent> <leader>M :call <SID>ToggleNote()<CR>

" ------------------------------------------------------------
" which-key hints (buffer-local)
" ------------------------------------------------------------
if has('nvim')
lua << WKEOF
local ok, wk = pcall(require, 'which-key')
if ok then
  wk.add({
    buffer = 0,
    { '<leader>S', desc = 'Barre ~~...~~ (bascule)' },
    { '<leader>S', desc = 'Barre ~~...~~ (selection)', mode = 'v' },
    { '<leader>N', desc = 'Nouvelle ligne « NOTE: »' },
    { '<leader>M', desc = 'Prefixe « NOTE: » (bascule)' },
  })
end
WKEOF
endif
