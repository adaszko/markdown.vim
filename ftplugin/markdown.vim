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

function! s:error(msg) " {{{
    echohl ErrorMsg
    echo 'markdown.vim:' a:msg
    echohl None
endfunction " }}}

function! LookingAt(regex) " {{{
    let start = 0
    let line = getline(".")
    let [_, lnum, col, _] = getpos(".")

    while 1
        if start > col
            break
        endif

        let matchpos = match(line, a:regex, start)
        if matchpos == -1
            break
        endif

        let matchlen = strlen(matchstr(strpart(line, matchpos), a:regex))
        if matchlen == 0
            throw 'LookingAt: Zero-length match for regex: ' . a:regex
        endif

        if matchpos <= col && col <= matchpos + matchlen
            return [strpart(line, matchpos, matchlen), lnum, matchpos, matchlen]
        endif

        let start += matchlen
    endwhile

    return ["", -1, -1, -1]
endfunction " }}}

function! ReplaceAt(lnum, col, len, replacement) " {{{
    let line = getline(a:lnum)
    let prefix = strpart(line, 0, a:col)
    let suffix = strpart(line, a:col+a:len)
    let line = prefix . a:replacement . suffix
    call setline(a:lnum, line)
endfunction! " }}}

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
    let [markdown_link, _, _, _] = LookingAt(markdown_link_regex)
    if markdown_link != ''
        let url = matchstr(markdown_link, '\v\[[^]]+\]\(\zs[^)]+\ze\)')
        let url = escape(url, '#%&')
        call OpenURL(url)
        return
    endif

    let bare_url_regex = '\vhttps?://\S+'
    let [bare_url, _, _, _] = LookingAt(bare_url_regex)
    if bare_url != ''
        let url = escape(bare_url, '#%&')
        call OpenURL(url)
        return
    endif

    call s:warning('No URL at point')
endfunction " }}}

function! MarkdownRetrieveURLTitle(url) " {{{
    execute "python" printf("url = '%s'", escape(a:url, "'"))
    python import requests, bs4
    python from requests.packages.urllib3.exceptions import InsecureRequestWarning
    python requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
    python resp = requests.get(url, verify=False)
    let status_code = pyeval('resp.status_code')
    if status_code != 200
        throw printf('MarkdownRetrieveURLTitle: %s: Unexpected HTTP status code', status_code)
    endif
    let content_type = pyeval('resp.headers.get("content-type", "").split(";")[0]')
    if content_type != 'text/html'
        throw printf('MarkdownRetrieveURLTitle: %s: Unexpected Content-Type', content_type)
    endif
    python soup = bs4.BeautifulSoup(resp.content, 'html.parser')
    python title = soup.find('title').text
    python title = ' '.join(l.strip() for l in title.splitlines())
    return pyeval('title')
endfunction " }}}

function! MarkdownTitlifyURLAtPoint() " {{{
    let bare_url_regex = '\vhttps?://\S+'
    let [url, lnum, matchpos, matchlen] = LookingAt(bare_url_regex)
    if url == ''
        call s:warning('No URL at point')
        return
    endif

    try
        let title = MarkdownRetrieveURLTitle(url)
    catch /MarkdownRetrieveURLTitle:.*/
        call s:error(v:exception)
        return
    endtry

    let replacement = printf("[%s](%s)", title, url)
    call ReplaceAt(lnum, matchpos, matchlen, replacement)
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
