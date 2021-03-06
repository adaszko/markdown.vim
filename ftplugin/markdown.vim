" This code is based on Jeremy Mack's Markdown ftplugin.
" Helpful: https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet


if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1


let s:cpo_save = &cpo
set cpo&vim


setlocal foldtext=markdown#get_fold_text()
setlocal foldexpr=markdown#get_fold_level(v:lnum)
setlocal foldmethod=expr

setlocal nocindent
setlocal nosmartindent
setlocal autoindent
setlocal indentexpr=markdown#get_indent(v:lnum)


let &cpo = s:cpo_save
unlet s:cpo_save

" vim:foldmethod=marker
