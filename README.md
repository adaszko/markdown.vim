# markdown.vim

Extends Vim’s default Markdown ftplugin with three features:

 * Open URL at cursor
 * Insert Markdown-style website title for the URL at point (supports both HTML and PDF)
 * Folding

## Installation
### minpac

```VimL
call minpac#add('https://github.com/adaszko/markdown.vim.git')
```

### `.vimrc`

```VimL
autocmd FileType markdown nnoremap <silent> <buffer> <CR> :call markdown#open_link_at_point()<CR>
autocmd FileType markdown nnoremap <silent> <buffer> <Tab> :call markdown#titlify_url_at_point()<CR>
autocmd FileType markdown noremap <silent> <buffer> <LocalLeader><Tab> :call markdown#toggle_done_status()<CR>
autocmd FileType markdown noremap <silent> <buffer> <LocalLeader>t :call markdown#toggle_task_status()<CR>
```

## Author

Adam Szkoda <adaszko@gmail.com>

## License

GPL3
