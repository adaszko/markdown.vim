" This code is based on Jeremy Mack's Markdown ftplugin.
" Helpful: https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet


if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1


let s:cpo_save = &cpo
set cpo&vim


function! s:warning(msg) " {{{
    echohl WarningMsg
    echo 'markdown.vim:' a:msg
    echohl None
endfunction " }}}

function! LookingAt(regex) " {{{
    let start = 0
    let line = getline(".")
    let [_, _, curcol, _] = getpos(".")

    while 1
        if start > curcol
            break
        endif

        let matchpos = match(line, a:regex, start)
        if matchpos == -1
            break
        endif

        let matchlen = strlen(matchstr(strpart(line, matchpos), a:regex))
        if matchlen == 0
            throw 'Zero-length match for regex: ' . a:regex
        endif

        if matchpos <= curcol && curcol <= matchpos + matchlen
            return strpart(line, matchpos, matchlen)
        endif

        let start += matchlen
    endwhile

    return ""
endfunction " }}}

function! OpenURL(url) " {{{
    if has('mac')
        silent execute '!open ' . a:url
        return
    endif

    if has('win32')
        let cmd = printf('!cmd /c start "" "%s"', a:url)
        silent execute cmd
        return
    endif

    call s:warning('Unknown OS')
endfunction " }}}

function! MarkdownOpenLinkAtPoint() " {{{
    let markdown_link_regex = '\v\[[^]]+\]\(\S+\)'
    let markdown_link = LookingAt(markdown_link_regex)
    if markdown_link != ''
        let url = matchstr(markdown_link, '\v\[[^]]+\]\(\zs[^)]+\ze\)')
        let url = escape(url, '#%&')
        call OpenURL(url)
        return
    endif

    let bare_url_regex = '\vhttps?://\S+'
    let bare_url = LookingAt(bare_url_regex)
    if bare_url != ''
        let url = escape(bare_url, '#%&')
        call OpenURL(url)
        return
    endif

    call s:warning('No URL at point')
endfunction " }}}

function! GetMarkdownFoldLevel(lnum) " {{{
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

function! MarkdownFoldText() " {{{
    let first = getline(v:foldstart)
    let nlines = v:foldend - v:foldstart
    return first . ' ' . printf('[%d]', nlines)
endfunction " }}}

setlocal foldtext=MarkdownFoldText()
setlocal foldexpr=GetMarkdownFoldLevel(v:lnum)
setlocal foldmethod=expr


let &cpo = s:cpo_save
unlet s:cpo_save

" vim:foldmethod=marker
