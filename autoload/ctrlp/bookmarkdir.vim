" =============================================================================
" File:          autoload/ctrlp/bookmarkdir.vim
" Description:   Bookmarked directories extension
" Author:        Kien Nguyen <github.com/kien>
" =============================================================================

" Init {{{1
if exists('g:loaded_ctrlp_bookmarkdir') && g:loaded_ctrlp_bookmarkdir
	fini
en
let g:loaded_ctrlp_bookmarkdir = 1

cal add(g:ctrlp_ext_vars, {
	\ 'init': 'ctrlp#bookmarkdir#init()',
	\ 'accept': 'ctrlp#bookmarkdir#accept',
	\ 'lname': 'bookmarked dirs',
	\ 'sname': 'bkd',
	\ 'type': 'tabs',
	\ 'opmul': 1,
	\ 'nolim': 1,
	\ 'wipe': 'ctrlp#bookmarkdir#remove',
	\ })

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
" Utilities {{{1
fu! s:getinput(str, ...)
	echoh Identifier
	cal inputsave()
	let input = call('input', a:0 ? [a:str] + a:000 : [a:str])
	cal inputrestore()
	echoh None
	retu input
endf

fu! s:cachefile()
	if !exists('s:cadir') || !exists('s:cafile')
		let s:cadir = ctrlp#utils#cachedir().ctrlp#utils#lash().'bkd'
		let s:cafile = s:cadir.ctrlp#utils#lash().'cache.txt'
	en
	retu s:cafile
endf

fu! s:writecache(lines)
	cal ctrlp#utils#writecache(a:lines, s:cadir, s:cafile)
endf

fu! s:getbookmarks()
	retu ctrlp#utils#readfile(s:cachefile())
endf

fu! s:savebookmark(name, cwd)
	let cwds = exists('+ssl') ? [tr(a:cwd, '\', '/'), tr(a:cwd, '/', '\')] : [a:cwd]
	let entries = filter(s:getbookmarks(), 'index(cwds, s:parts(v:val)[1]) < 0')
	cal s:writecache(insert(entries, a:name.'	'.a:cwd))
endf

fu! s:setentries()
	let time = getftime(s:cachefile())
	if !( exists('s:bookmarks') && time == s:bookmarks[0] )
		let s:bookmarks = [time, s:getbookmarks()]
	en
endf

" prev: fu! s:parts(str, ...)
" prev: 	let mlist = matchlist(a:str, '\v([^\t]+)\t(.*)$')
" prev: 	" prev: retu mlist != [] ? mlist[1:2] : ['', '']
" prev: 	if empty(mlist)
" prev: 		retu ['', '']
" prev: 	en
" prev: 	let mlist = mlist[1:2]
" prev: 	if a:0 == 0
" prev: 		retu mlist
" prev: 	en
" prev: 
" prev: 	let dir = mlist[1]
" prev: 	" prev: let modify_str = get(a:000, 0, '')
" prev: 	let modify_str = a:1
" prev: 	if !empty(modify_str)
" prev: 		let fnamemodflags = ''
" prev: 		if modify_str[0] ==# ':'
" prev: 			let fnamemodflags = modify_str
" prev: 		elsei modify_str ==# 'u'
" prev: 			let fnamemodflags = ':.'
" prev: 		elsei modify_str ==# 'f'
" prev: 			let dir = ctrlp#utils#normalizepathname(dir)
" prev: 		el
" prev: 			echoe printf('ERROR: ctrlp#bookmarkdir::s:parts(): invalid modify_str arg: %s', modify_str)
" prev: 		en
" prev: 		if !empty(fnamemodflags)
" prev: 			let dir = fnamemodify(dir, fnamemodflags)
" prev: 		en
" prev: 		let mlist[1] = dir
" prev: 	en
" prev: 	retu mlist
" prev: endf
fu! s:parts(str, ...)
	let mlist = matchlist(a:str, '\v([^\t]+)\t(.*)$')
	" prev: retu mlist != [] ? mlist[1:2] : ['', '']
	if empty(mlist)
		retu ['', '']
	en
	let mlist = mlist[1:2]
	if a:0 == 0
		retu mlist
	en
	let mlist[1] = ctrlp#utils#modifypathname(mlist[1], a:1)
	retu mlist
endf

fu! s:process(entries, type)
	retu map(a:entries, 's:modify(v:val, a:type)')
endf

fu! s:modify(entry, type)
	let [name, dir] = s:parts(a:entry, a:type)
	" prev: let dir = fnamemodify(dir, a:type)
	retu name.'	'.( dir == '' ? '.' : dir )
endf

fu! s:msg(name, cwd)
	redr
	echoh Identifier | echon 'Bookmarked ' | echoh Constant
	echon a:name.' ' | echoh Directory | echon a:cwd
	echoh None
endf

fu! s:syntax()
	if !ctrlp#nosy()
		cal ctrlp#hicheck('CtrlPBookmark', 'Identifier')
		cal ctrlp#hicheck('CtrlPTabExtra', 'Comment')
		sy match CtrlPBookmark '^> [^\t]\+' contains=CtrlPLinePre
		sy match CtrlPTabExtra '\zs\t.*\ze$'
	en
endf
" Public {{{1
fu! ctrlp#bookmarkdir#init()
	cal s:setentries()
	cal s:syntax()
	retu s:process(copy(s:bookmarks[1]), ':.')
endf

fu! ctrlp#bookmarkdir#accept(mode, str)
	let parts = s:parts(s:modify(a:str, ':p'))
	cal call('s:savebookmark', parts)
	if a:mode =~ 't\|v\|h'
		cal ctrlp#exit()
	en
	cal ctrlp#setdir(parts[1], a:mode =~ 't\|h' ? 'chd!' : 'lc!')
	if a:mode == 'e'
		cal ctrlp#switchtype(0)
		cal ctrlp#recordhist()
		cal ctrlp#prtclear()
	en
endf

fu! ctrlp#bookmarkdir#add(bang, dir, ...)
	let ctrlp_tilde_homedir = get(g:, 'ctrlp_tilde_homedir', 0)
	let cwd = fnamemodify(getcwd(), ctrlp_tilde_homedir ? ':p:~' : ':p')
	let dir = fnamemodify(a:dir, ctrlp_tilde_homedir ? ':p:~' : ':p')
	if a:bang == '!'
		let cwd = dir != '' ? dir : cwd
		let name = a:0 && a:1 != '' ? a:1 : cwd
	el
		let str = 'Directory to bookmark: '
		let cwd = dir != '' ? dir : s:getinput(str, cwd, 'dir')
		if cwd == '' | retu | en
		let name = a:0 && a:1 != '' ? a:1 : s:getinput('Bookmark as: ', cwd)
		if name == '' | retu | en
	en
	let name = tr(name, '	', ' ')
	cal s:savebookmark(name, cwd)
	cal s:msg(name, cwd)
endf

fu! ctrlp#bookmarkdir#remove(entries)
	let entries = s:process(copy(a:entries), 'a')
	cal s:writecache(entries == [] ? [] :
		\ filter(s:getbookmarks(), 'index(entries, s:modify(v:val, "a")) < 0'))
	cal s:setentries()
	retu s:process(copy(s:bookmarks[1]), 'u')
endf

fu! ctrlp#bookmarkdir#id()
	retu s:id
endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
