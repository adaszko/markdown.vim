" This code is based on Jeremy Mack's Markdown ftplugin.
" Helpful: https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet


if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1


let s:cpo_save = &cpo
set cpo&vim


function! g:get_markdown_fold_level(lnum) " {{{
    let line = getline(a:lnum)

    if line =~ '^#'
        return '>' . matchend(line, '\v^#+')
    endif

    let next = getline(a:lnum + 1)

    if next =~ '\v^--+'
        return '>2'
    endif

    if next =~ '\v^\=\=+'
        return '>1'
    endif

    return '='
endfunction " }}}

function! g:markdown_fold_text() " {{{
    let first = getline(v:foldstart)
    let nlines = v:foldend - v:foldstart
    return first . ' ' . printf('[%d]', nlines)
endfunction " }}}

setlocal foldtext=g:markdown_fold_text()
setlocal foldexpr=g:get_markdown_fold_level(v:lnum)
setlocal foldmethod=expr


let &cpo = s:cpo_save
unlet s:cpo_save

" vim:foldmethod=marker
