# markdown.vim

Extends Vim’s default Markdown ftplugin with three features (point = cursor):

 * Open URL at point
 * Insert Markdown-style website title for the URL at point
 * Folding

## Installation

Assuming you have Pathogen up and running:

    $ cd ~/.vim/bundle
    $ git clone git://github.com/adaszko/markdown.vim

`MarkdownTitlifyURLAtPoint()` requires a Vim installation with Python support enabled:

```
:python print 1
1
```

and also requires that you have `requests` and `bs4` installed from PyPI:

```
$ pip install requests bs4
```

To map exported functions to keys, add this to your `.vimrc`:

```
augroup my_markdown " {{{
    autocmd!
    autocmd FileType markdown noremap <silent> <buffer> <CR> :call MarkdownOpenLinkAtPoint()<CR>
    autocmd FileType markdown noremap <silent> <buffer> <Tab> :call MarkdownTitlifyURLAtPoint()<CR>
augroup END " }}}
```

## Author

Adam Szkoda <adaszko@gmail.com>

## License

BSD3
