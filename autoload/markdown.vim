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
    if a:spaces == 1
        return a:spaces - 1 + &shiftwidth
    endif

    return a:spaces + &shiftwidth
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
        let preceding_line_number = prevnonblank(a:lnum - 1)
        " The first bullet point has a fixed indentation
        if preceding_line_number == 0
            return 1
        endif

        let preceding_line = getline(preceding_line_number)

        if markdown#is_heading_line(preceding_line)
            return 1
        endif

        let preceding_line_indent = markdown#get_line_indent(preceding_line)

        " Assume the preceding line has to be indented already
        if !markdown#is_bullet_point_indentation(preceding_line_indent)
            return -1
        endif

        let current_line_indent = markdown#get_line_indent(line)
        if current_line_indent < preceding_line_indent
            return preceding_line_indent
        endif

        if current_line_indent == preceding_line_indent
            return -1
        endif

        if current_line_indent > preceding_line_indent
            return markdown#increase_indent(preceding_line_indent)
        endif

        return 1
    endif

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

" vim:foldmethod=marker
