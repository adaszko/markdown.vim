function! markdown#warning(msg) " {{{
    echohl WarningMsg
    echo 'markdown.vim:' a:msg
    echohl None
endfunction " }}}

function! markdown#error(msg) " {{{
    echohl ErrorMsg
    echo 'markdown:' a:msg
    echohl None
endfunction " }}}

function! markdown#looking_at(regex) " {{{
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

function! markdown#replace_at(lnum, col, len, replacement) " {{{
    let line = getline(a:lnum)
    let prefix = strpart(line, 0, a:col)
    let suffix = strpart(line, a:col+a:len)
    let line = prefix . a:replacement . suffix
    call setline(a:lnum, line)
endfunction! " }}}

function! markdown#open_url(url) " {{{
    if has('mac')
        silent execute '!open ' . escape(shellescape(a:url), "#!$%")
        return
    endif

    call markdown#warning('Unknown OS')
endfunction " }}}

function! markdown#get_url_at_point() " {{{
    let markdown_link_regex = '\v\[[^]]+\]\(\S+\)'
    let [markdown_link, _, _, _] = markdown#looking_at(markdown_link_regex)
    if markdown_link != ''
        let url = matchstr(markdown_link, '\v\[[^]]+\]\(\zs[^)]+\ze\)')
        return url
    endif

    let bare_url_regex = '\vhttps?://\S+'
    let [bare_url, _, _, _] = markdown#looking_at(bare_url_regex)
    if bare_url != ''
        return bare_url
    endif

    let note_url_regex = '\vnote://'
    let [note_url, _, _, _] = markdown#looking_at(note_url_regex)
    if note_url != ''
        return note_url
    endif

    return ''
endfunction " }}}

function! markdown#open_link_at_point() " {{{
    let url = markdown#get_url_at_point()

    if url =~ '\v^https?://' || url =~ '\v^file://'
        call markdown#open_url(url)
    elseif url =~ '\v^note://'
        execute 'edit' url
    elseif url == ''
        call markdown#warning('No URL at point')
    endif
endfunction " }}}

function! markdown#retrieve_url_title(url) " {{{
    execute "python3" printf("url = '%s'", escape(a:url, "'"))
    python3 import requests, bs4
    python3 import requests.packages.urllib3
    python3 requests.packages.urllib3.disable_warnings()
    python3 headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36'}
    python3 head = requests.head(url, verify=False, headers=headers, allow_redirects=True, timeout=2)
    let head_status_code = pyxeval('head.status_code')
    if head_status_code != 405
        if head_status_code != 200
            throw printf('markdown#retrieve_url_title: %s: Unexpected HTTP status code', head_status_code)
        endif
        let content_type = pyxeval('head.headers.get("content-type", "").split(";")[0]')
        if content_type != 'text/html'
            throw printf('markdown#retrieve_url_title: %s: Unexpected Content-Type', content_type)
        endif
    endif
    python3 resp = requests.get(url, verify=False, headers=headers, timeout=3)
    let status_code = pyxeval('resp.status_code')
    if status_code != 200
        throw printf('markdown#retrieve_url_title: %s: Unexpected HTTP status code', status_code)
    endif
    let content_type = pyxeval('resp.headers.get("content-type", "").split(";")[0]')
    if content_type != 'text/html'
        throw printf('markdown#retrieve_url_title: %s: Unexpected Content-Type', content_type)
    endif
    python3 soup = bs4.BeautifulSoup(resp.content, 'html.parser')
    python3 title_tag = soup.find('title')
    if pyxeval('title_tag is None')
        throw 'markdown#retrieve_url_title: Title tag not found'
    endif
    python3 title = ' '.join(l.strip() for l in title_tag.text.splitlines()).strip()
    python3 <<EOF
import re
m = re.match('^GitHub - [^/]+/(.*)', title)
if m is not None:
    title = m.groups()[0]

if title.startswith('GitHub -'):
    title = title[len('GitHub - '):]

if title.endswith(' - YouTube'):
    title = title[:-len(' - YouTube')]

title = title.rstrip('.')
EOF
    return pyxeval('title')
endfunction " }}}

function! markdown#titlify_url_at_point() " {{{
    let bare_url_regex = '\vhttps?://\S+'
    let [url, lnum, matchpos, matchlen] = markdown#looking_at(bare_url_regex)
    if url == ''
        call markdown#warning('No URL at point')
        return
    endif

    try
        let title = markdown#retrieve_url_title(url)
    catch /markdown#retrieve_url_title:.*/
        call markdown#error(v:exception)
        return
    endtry

    let replacement = printf("[%s](%s)", title, url)
    call markdown#replace_at(lnum, matchpos, matchlen, replacement)
endfunction " }}}

function! markdown#get_line_indent(line) " {{{
    return len(matchstr(a:line, '\v\s*'))
endfunction " }}}

function! markdown#is_bullet_point_indentation(spaces) " {{{
    " Assuming &shiftwidth == 4, good-looking bullet points indentations are
    " from a sequence: 1, 4, 8, 12, ...

    if a:spaces < 1
        return 0
    endif

    if a:spaces == 1
        return 1
    endif

    return a:spaces % &shiftwidth == 0
endfunction " }}}

function! markdown#increase_indent(spaces) " {{{
    if a:spaces == 0
        return 1
    endif

    if a:spaces == 1
        return a:spaces - 1 + &shiftwidth
    endif

    return (a:spaces - (a:spaces % &shiftwidth)) + &shiftwidth
endfunction " }}}

function! markdown#is_heading_line(line) " {{{
    return a:line =~# '\v^\s*#'
endfunction " }}}

function! markdown#get_indent(lnum) " {{{
    let line = getline(a:lnum)

    " Header
    if markdown#is_heading_line(line)
        return 0
    endif

    " Bulleted list
    if line =~# '\v^\s*\*'
        let current_line_indent = markdown#get_line_indent(line)
        if markdown#is_bullet_point_indentation(current_line_indent)
            return -1
        else
            return markdown#increase_indent(current_line_indent)
        endif
        return -1
    endif

    " Blockquote
    if line =~ '\v^\s*\>'
        return 0
    endif

    return -1
endfunction " }}}

function! markdown#get_fold_level(lnum) " {{{
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

function! markdown#get_fold_text() " {{{
    let first = getline(v:foldstart)
    let nlines = v:foldend - v:foldstart
    return first . ' ' . printf('[%d]', nlines)
endfunction " }}}

function! markdown#toggle_done_status_of_line(lnum) " {{{
    let line = getline(a:lnum)

    function! s:cycle_done_status(everything, prefix, status, date, suffix)
        if a:status == " "
            let today = strftime("%F")
            return printf("%s [✓] %s %s", a:prefix, today, a:suffix)
        elseif a:status == "✓"
            let today = strftime("%F")
            return printf("%s [✗] %s %s", a:prefix, today, a:suffix)
        elseif a:status == "✗"
            return printf("%s [ ] %s", a:prefix, a:suffix)
        else
            return a:everything
        endif
    endfunction

    let updated = substitute(line, '\v^(\s*%(\*|\=\>|\<\=))\s*\[([ ✓✗])\]\s*([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])?\s*(.*)', {m -> s:cycle_done_status(m[0], m[1], m[2], m[3], m[4])}, '')
    if line != updated
        call setline(a:lnum, updated)
    endif
endfunction " }}}

function! markdown#toggle_done_status() range " {{{
    let lnum = a:firstline
    while lnum <= a:lastline
        call markdown#toggle_done_status_of_line(lnum)
        let lnum += 1
    endwhile
endfunction " }}}

function! markdown#toggle_task_status_of_line(lnum) " {{{
    let line = getline(a:lnum)

    function! s:cycle_done_status(everything, prefix, status, suffix)
        if a:status == ""
            return printf("%s [ ] %s", a:prefix, a:suffix)
        elseif a:status == "[ ]" || a:status == "[x]" || a:status == "[X]" || a:status == "[✓]" || a:status == "[✗]"
            return printf("%s %s", a:prefix, a:suffix)
        else
            return a:everything
        endif
    endfunction

    let updated = substitute(line, '\c\v^(\s*%(\*|\=\>|\<\=))\s*(\[[ x✓✗]\])?\s*(.*)', {m -> s:cycle_done_status(m[0], m[1], m[2], m[3])}, '')
    if line != updated
        call setline(a:lnum, updated)
    endif
endfunction " }}}

function! markdown#toggle_task_status() range " {{{
    let lnum = a:firstline
    while lnum <= a:lastline
        call markdown#toggle_task_status_of_line(lnum)
        let lnum += 1
    endwhile
endfunction " }}}

" vim:foldmethod=marker
