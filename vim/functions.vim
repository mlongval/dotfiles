" Function: Jump to tag or custom definition
function! JumpToDef()
    if exists("*GotoDefinition_" . &filetype)
        call GotoDefinition_{&filetype}()
    else
        exe "norm! \<C-]>"
    endif
endfunction

" Function: Exit Vim if at beginning of buffer
function! ExitAtBufferStart()
  if line('.') == 1 && col('.') == 1
    quit
  else
    execute "normal! \<BS>"
  endif
endfunction

" Function: Add space at EOL and jump to next line
function! EndOfLineTab()
    if col('.') == col('$')
        if line('.') == line('$')
            call append(line('.'), '')
        endif
        normal! j
        StripWhitespace
        normal! A
        normal! $
    endif
endfunction

" Function: Print to PDF (Desktop)
function! PrintToPdf()
    let pdf_path = '~/Desktop/' . fnamemodify(expand('%:t'), ':r') . '.ps'
    silent! execute 'hardcopy' . '> ' . pdf_path
    silent! execute '!ps2pdf ' . pdf_path . ' ' . pdf_path[:-3] . 'pdf'
    silent! execute '!rm ' . pdf_path
endfunction

" Function: Print to PDF in current directory
function! PrintToPdf_PWD()
    let full_name = expand('%')
    let ps_path = full_name . '.ps'
    let pdf_output = full_name . '.pdf'
    silent execute '!paps ' . fnameescape(full_name) . ' --font=Monospace --paper letter > ' . fnameescape(ps_path) . ' 2>/dev/null'
    silent execute '!ps2pdf ' . fnameescape(ps_path) . ' ' . fnameescape(pdf_output) . ' > /dev/null 2>&1'
    silent execute '!rm ' . fnameescape(ps_path)
    silent execute '!mkdir -p PDF'
    silent execute '!mv ' . fnameescape(pdf_output) . ' PDF/'
    redraw!
endfunction

" Function: Print to PDF with date suffix
function! PrintToPdf_PWD_with_date()
    let full_name = expand('%')
    let ps_path = full_name . '.ps'
    let pdf_output = full_name . '_' . trim(expand('%:p:h:t')) . '.pdf'
    silent execute '!paps ' . fnameescape(full_name) . ' --font=Monospace --paper letter > ' . fnameescape(ps_path) . ' 2>/dev/null'
    silent execute '!ps2pdf ' . fnameescape(ps_path) . ' ' . fnameescape(pdf_output) . ' > /dev/null 2>&1'
    silent execute '!rm ' . fnameescape(ps_path)
    silent execute '!mkdir -p PDF'
    silent execute '!mv ' . fnameescape(pdf_output) . ' PDF/'
    redraw!
endfunction
