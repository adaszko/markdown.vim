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
    echo 'markdown:' a:msg
    echohl None
endfunction " }}}

function! s:LookingAt(regex) " {{{
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

function! s:ReplaceAt(lnum, col, len, replacement) " {{{
    let line = getline(a:lnum)
    let prefix = strpart(line, 0, a:col)
    let suffix = strpart(line, a:col+a:len)
    let line = prefix . a:replacement . suffix
    call setline(a:lnum, line)
endfunction! " }}}

function! s:OpenURL(url) " {{{
    if has('mac')
        silent execute '!open ' . escape(shellescape(a:url), "#!$%")
        return
    endif

    call s:warning('Unknown OS')
endfunction " }}}

function! s:MarkdownOpenLinkAtPoint() " {{{
    let markdown_link_regex = '\v\[[^]]+\]\(\S+\)'
    let [markdown_link, _, _, _] = s:LookingAt(markdown_link_regex)
    if markdown_link != ''
        let url = matchstr(markdown_link, '\v\[[^]]+\]\(\zs[^)]+\ze\)')
        call s:OpenURL(url)
        return
    endif

    let bare_url_regex = '\vhttps?://\S+'
    let [bare_url, _, _, _] = s:LookingAt(bare_url_regex)
    if bare_url != ''
        call s:OpenURL(bare_url)
        return
    endif

    call s:warning('No URL at point')
endfunction " }}}

function! s:MarkdownRetrieveURLTitle(url) " {{{
    execute "python3" printf("url = '%s'", escape(a:url, "'"))
    python3 import requests, bs4
    python3 import requests.packages.urllib3
    python3 requests.packages.urllib3.disable_warnings()
    python3 headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36'}
    python3 resp = requests.get(url, verify=False, headers=headers)
    let status_code = pyxeval('resp.status_code')
    if status_code != 200
        throw printf('MarkdownRetrieveURLTitle: %s: Unexpected HTTP status code', status_code)
    endif
    let content_type = pyxeval('resp.headers.get("content-type", "").split(";")[0]')
    if content_type != 'text/html'
        throw printf('MarkdownRetrieveURLTitle: %s: Unexpected Content-Type', content_type)
    endif
    python3 soup = bs4.BeautifulSoup(resp.content, 'html.parser')
    python3 title_tag = soup.find('title')
    if pyxeval('title_tag is None')
        throw 'MarkdownRetrieveURLTitle: Title tag not found'
    endif
    python3 title = ' '.join(l.strip() for l in title_tag.text.splitlines()).strip()
    return pyxeval('title')
endfunction " }}}

function! s:MarkdownTitlifyURLAtPoint() " {{{
    let bare_url_regex = '\vhttps?://\S+'
    let [url, lnum, matchpos, matchlen] = s:LookingAt(bare_url_regex)
    if url == ''
        call s:warning('No URL at point')
        return
    endif

    try
        let title = s:MarkdownRetrieveURLTitle(url)
    catch /MarkdownRetrieveURLTitle:.*/
        call s:error(v:exception)
        return
    endtry

    let replacement = printf("[%s](%s)", title, url)
    call s:ReplaceAt(lnum, matchpos, matchlen, replacement)
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


nnoremap <Plug>MarkdownTitlifyURLAtPoint :<C-U>call <SID>MarkdownTitlifyURLAtPoint()<CR>
nnoremap <Plug>MarkdownOpenLinkAtPoint :<C-U>call <SID>MarkdownOpenLinkAtPoint()<CR>


let &cpo = s:cpo_save
unlet s:cpo_save

" vim:foldmethod=marker
