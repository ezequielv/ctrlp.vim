" =============================================================================
" File:          autoload/ctrlp/utils.vim
" Description:   Utilities
" Author:        Kien Nguyen <github.com/kien>
" =============================================================================

" Static variables {{{1
fu! ctrlp#utils#lash()
	retu &ssl || !exists('+ssl') ? '/' : '\'
endf

fu! s:lash(...)
	retu ( a:0 ? a:1 : getcwd() ) !~ '[\/]$' ? s:lash : ''
endf

fu! ctrlp#utils#opts()
	let s:lash = ctrlp#utils#lash()
	let usrhome = $HOME . s:lash( $HOME )
	let cahome = exists('$XDG_CACHE_HOME') ? $XDG_CACHE_HOME : usrhome.'.cache'
	let cadir = isdirectory(usrhome.'.ctrlp_cache')
		\ ? usrhome.'.ctrlp_cache' : cahome.s:lash(cahome).'ctrlp'
	if exists('g:ctrlp_cache_dir')
		let cadir = expand(g:ctrlp_cache_dir, 1)
		if isdirectory(cadir.s:lash(cadir).'.ctrlp_cache')
			let cadir = cadir.s:lash(cadir).'.ctrlp_cache'
		en
	en
	let s:cache_dir = cadir
endf
cal ctrlp#utils#opts()

let s:wig_cond = v:version > 702 || ( v:version == 702 && has('patch051') )
" Files and Directories {{{1
fu! ctrlp#utils#cachedir()
	retu s:cache_dir
endf

fu! ctrlp#utils#cachefile(...)
	let [tail, dir] = [a:0 == 1 ? '.'.a:1 : '', a:0 == 2 ? a:1 : getcwd()]
	let cache_file = substitute(dir, '\([\/]\|^\a\zs:\)', '%', 'g').tail.'.txt'
	retu a:0 == 1 ? cache_file : s:cache_dir.s:lash(s:cache_dir).cache_file
endf

fu! ctrlp#utils#readfile(file)
	if filereadable(a:file)
		let data = readfile(a:file)
		if empty(data) || type(data) != 3
			unl data
			let data = []
		en
		retu data
	en
	retu []
endf

fu! ctrlp#utils#mkdir(dir)
	if exists('*mkdir') && !isdirectory(a:dir)
		sil! cal mkdir(a:dir, 'p')
	en
	retu a:dir
endf

let s:virtual_fname_separators = [
	\		':/',
	\		'::',
	\ ]

" TODO: deal with dos/windows full paths
" TODO: extract the "protocol" component ('len(split(a:fname, '://')[0]) > 1'?)
" TODO: make sure we deal with all the "virtual" names: tar, gz, all netrw (remote?), etc.
fu! ctrlp#utils#fname_is_virtual(fname) abort
	" prev: retu (
	" prev: 			\		empty(a:fname)
	" prev: 			\		||
	" prev: 			\		(stridx(a:fname, '://') >= 0)
	" prev: 			\	)
	if empty(a:fname) | retu 1 | en
	for sep in s:virtual_fname_separators
		let fname_parts = split(a:fname, sep)
		if (len(fname_parts) > 1) && (len(fname_parts[0]) > 1)
			retu 1
		en
	endfo
	retu 0
endf

fu! ctrlp#utils#can_remove_directories() abort
	if !exists('s:can_remove_directories_result')
		let res = exists('*mkdir')
		if res
			try
				" try to call the delete() version that supports the {flags} parameter
				" (in particular, the 'd' arg).
				" idea: remove a non-existing file/directory, which should fail
				" gracefully.
				cal delete(tempname(), 'd')
				" NOTE: the return value is not important to us (yet): we just wanted
				" to make sure that the call did not reutrn E118 (or any other
				" exceptions), and that it would fail gracefully.
			cat
				" MAYBE: use fallback:
				"  example: let res = has('unix') " we could do system(...) instead
				"  (or any other fallback condition)
				let res = 0
			endt
		en
		let s:can_remove_directories_result = !!res
	en
	retu s:can_remove_directories_result
endf

" same return value as 'delete()'
fu! ctrlp#utils#remove_directory(fname) abort
	if !ctrlp#utils#can_remove_directories() | retu -1 | en
	" for now, we only use vim's own version
	retu delete(a:fname, 'd')
endf

fu! ctrlp#utils#writecache(lines, ...)
	if isdirectory(ctrlp#utils#mkdir(a:0 ? a:1 : s:cache_dir))
		sil! cal writefile(a:lines, a:0 >= 2 ? a:2 : ctrlp#utils#cachefile())
	en
endf

" args:
"  - set_ignore_wildignore (default: 0)
fu! s:wig_state_get(...)
	let retval = {
				\ 'wig': &wig,
				\ 'su': &su,
				\ }
	if a:0 && a:1
		" prev: set wig= su=
		set wig=
	en
	retu retval
endf

fu! s:wig_state_set(wig_state)
	let &wig = a:wig_state['wig']
	let &su = a:wig_state['su']
endf

fu! ctrlp#utils#glob(...)
	let path = ctrlp#utils#fnesc(a:1, 'g')
	" prev: retu s:wig_cond ? glob(path, a:2) : glob(path)
	let glob_flag = a:2
	if s:wig_cond
		retu glob(path, glob_flag)
	en
	try
		if glob_flag
			let wig_state = s:wig_state_get(!0)
		en
		retu glob(path)
	fina
		if glob_flag
			cal s:wig_state_set(wig_state)
		en
	endt
endf

fu! ctrlp#utils#globpath(...)
	" prev: retu call('globpath', s:wig_cond ? a:000 : a:000[:1])
	if s:wig_cond
		retu call('globpath', a:000)
	en
	let glob_flag = get(a:000, 2, 0)
	try
		if glob_flag
			let wig_state = s:wig_state_get(!0)
		en
		retu call('globpath', a:000[:1])
	fina
		if glob_flag
			cal s:wig_state_set(wig_state)
		en
	endt
endf

fu! ctrlp#utils#fnesc(path, type, ...)
	if exists('*fnameescape')
		if exists('+ssl')
			if a:type == 'c'
				let path = escape(a:path, '%#')
			elsei a:type == 'f'
				let path = fnameescape(a:path)
			elsei a:type == 'g'
				let path = escape(a:path, '?*')
			en
			let path = substitute(path, '[', '[[]', 'g')
		el
			let path = fnameescape(a:path)
		en
	el
		if exists('+ssl')
			if a:type == 'c'
				let path = escape(a:path, '%#')
			elsei a:type == 'f'
				let path = escape(a:path, " \t\n%#*?|<\"")
			elsei a:type == 'g'
				let path = escape(a:path, '?*')
			en
			let path = substitute(path, '[', '[[]', 'g')
		el
			let path = escape(a:path, " \t\n*?[{`$\\%#'\"|!<")
		en
	en
	retu a:0 ? escape(path, a:1) : path
endf

fu! ctrlp#utils#shellescape(p)
	" prev: if exists('s:shellescape')
	" prev: 	"? return call(s:shellescape, [a:p])
	" prev: 	return s:shellescape(a:p)
	" prev: endif
	" prev: if exists('*shellescape')
	" prev: 	let s:shellescape = function('shellescape')
	" prev: el
	" prev: 	function! s:shellescape(p)
	" prev: 		return escape(a:p, '\\/ "' . "'")
	" prev: 	endfunction
	" prev: en
	" prev: "? " delegate to the code at the beginning to perform the right call
	" prev: "? return ctrlp#utils#shellescape(a:p)
	" prev: return s:shellescape(a:p)
	if !exists('s:shellescape')
		if exists('*shellescape')
			let s:shellescape = function('shellescape')
		el
			function! s:shellescape(p)
				return escape(a:p, '\\/ "' . "'")
			endfunction
		en
	en
	return s:shellescape(a:p)
endf

let s:fnmflags_abs = ':p'
let s:fnmflags_home = ':p:~'

fu! ctrlp#utils#modifypathname(pathname, modify_str)
	let pathname = a:pathname
	let modify_str = a:modify_str

	if !empty(modify_str)
		let fnamemodflags = ''
		if modify_str[0] ==# ':' " fnamemodify() flags
			let fnamemodflags = modify_str
		elsei modify_str ==# 'u' " [u]ser
			let fnamemodflags = ':.'
		elsei modify_str ==# 'a' " [a]bsolute path
			let fnamemodflags = s:fnmflags_abs
		elsei modify_str ==# 'h' " based on [h]ome dir
			let fnamemodflags = s:fnmflags_home
		elsei modify_str =~# '\v^[fc]$' " [f]ile, [c]ache
			let fnamemodflags = get(g:, 'ctrlp_tilde_homedir', 0) ? s:fnmflags_home : s:fnmflags_abs
		el
			echoe printf('ERROR: ctrlp#bookmarkdir::s:parts(): invalid modify_str arg: %s', modify_str)
		en
		if !empty(fnamemodflags)
			let pathname = fnamemodify(pathname, fnamemodflags)
		en
	en
	retu pathname
endf

" done: remove this function, and replace it with direct calls to ctrlp#utils#modifypathname()
" prev: fu! ctrlp#utils#normalizepathname(pathname)
" prev: 	" prev: retu fnamemodify(a:pathname, get(g:, 'ctrlp_tilde_homedir', 0) ? ':p:~' : ':p')
" prev: 	retu ctrlp#utils#modifypathname(a:pathname, 'f')
" prev: endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
