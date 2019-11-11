" =============================================================================
" File:          autoload/ctrlp/tag.vim
" Description:   Tag file extension
" Author:        Kien Nguyen <github.com/kien>
" =============================================================================

" Init {{{1
if exists('g:loaded_ctrlp_tag') && g:loaded_ctrlp_tag
	fini
en
let g:loaded_ctrlp_tag = 1

cal add(g:ctrlp_ext_vars, {
	\ 'init': 'ctrlp#tag#init()',
	\ 'accept': 'ctrlp#tag#accept',
	\ 'lname': 'tags',
	\ 'sname': 'tag',
	\ 'enter': 'ctrlp#tag#enter()',
	\ 'type': 'tabs',
	\ })

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

let s:cfgvarname_pref = 'ctrlp_tag_'
let s:cfgvarname_customtagfiles = s:cfgvarname_pref . 'custom_tag_files'
"? let s:cfgvarname_stdtagfiles_index = s:cfgvarname_pref . 'stdtagfiles_index'

" TODO: implement s:has_tagfiles_data_from_userexpr()
" TODO: implement s:get_tagfiles_from_userexpr()
" prev: \		[ 'b:ctrlp_custom_tag_files' ],
" prev: \		[ 'b:' . s:cfgvarname_pref . 'custom_tag_files' ],
" prev: \				'get(b:, ''ctrlp_tag_use_gutentags_files'', get(g: ''ctrlp_tag_use_gutentags_files'', !0))' ],
" prev: \		[ 's:get_tagfiles_from_gutentags()', 's:getcfgval(''use_gutentags_files'', !0)' ],
" prev: \		[ 'g:ctrlp_custom_tag_files' ],
" prev: \		[ 'g:' . s:cfgvarname_pref . 'custom_tag_files' ],
" MAYBE: \		[ 's:get_stdtagfiles_userindex()', 's:uses_stdtagfiles_index()' ], " just before the last one
let s:get_tagfiles_proclist = [
	\		[ 'b:' . s:cfgvarname_customtagfiles ],
	\		[ 's:get_tagfiles_from_userexpr("b")', 's:has_tagfiles_data_from_userexpr("b")' ],
	\		[ 's:get_tagfiles_from_gutentags()', 's:has_tagfiles_data_from_gutentags()' ],
	\		[ 'g:' . s:cfgvarname_customtagfiles ],
	\		[ 's:get_tagfiles_from_userexpr("g")', 's:has_tagfiles_data_from_userexpr("g")' ],
	\		[ 'tagfiles()' ],
	\ ]
" Utilities {{{1
fu! s:findcount(str, tgaddr)
	let [tg, ofname] = split(a:str, '\t\+\ze[^\t]\+$')
	let tgs = taglist('^'.tg.'$')
	if len(tgs) < 2
		retu [0, 0, 0, 0]
	en
	let bname = fnamemodify(bufname('%'), ':p')
	let fname = expand(fnamemodify(simplify(ofname), ':s?^[.\/]\+??:p:.'), 1)
	let [fnd, cnt, pos, ctgs, otgs] = [0, 0, 0, [], []]
	for tgi in tgs
		let lst = bname == fnamemodify(tgi["filename"], ':p') ? 'ctgs' : 'otgs'
		cal call('add', [{lst}, tgi])
	endfo
	let ntgs = ctgs + otgs
	for tgi in ntgs
		let cnt += 1
		let fulname = fnamemodify(tgi["filename"], ':p')
		if stridx(fulname, fname) >= 0
			\ && strlen(fname) + stridx(fulname, fname) == strlen(fulname)
			let fnd += 1
			let pos = cnt
		en
	endfo
	let cnt = 0
	for tgi in ntgs
		let cnt += 1
		if tgi["filename"] == ofname
			if a:tgaddr != ""
				if a:tgaddr == tgi["cmd"]
					let [fnd, pos] = [0, cnt]
				en
			else
				let [fnd, pos] = [0, cnt]
			en
		en
	endfo
	retu [1, fnd, pos, len(ctgs)]
endf

fu! s:filter(tags)
	let nr = 0
	wh 0 < 1
		if a:tags == [] | brea | en
		if a:tags[nr] =~ '^!' && a:tags[nr] !~# '^!_TAG_'
			let nr += 1
			con
		en
		if a:tags[nr] =~# '^!_TAG_' && len(a:tags) > nr
			cal remove(a:tags, nr)
		el
			brea
		en
	endw
	retu a:tags
endf

fu! s:getcfgval(varsuf, defval)
	let varname = s:cfgvarname_pref . a:varsuf
	retu get(b:, varname, get(g:, varname, a:defval))
endf

fu! s:getcfg_skip_empty_lists()
	retu s:getcfgval('skip_empty_lists', 0)
endf

let s:gutentags_files_tf_keys = [ 'ctags' ]

fu! s:get_tagfiles_data_from_gutentags()
	let retval_nodata = [0, 0]
	let gtfiles_dict = get(b:, 'gutentags_files')
	if type(gtfiles_dict) != 4 | retu retval_nodata | en
	" MAYBE: add presence/value check for certain elements (or a non-empty dictionary, etc.)
	" fallback: return what we've got
	retu [1, gtfiles_dict]
endf

fu! s:has_tagfiles_data_from_gutentags()
	if !s:getcfgval('use_gutentags_files', !0) | retu 0 | en
	retu get(s:get_tagfiles_data_from_gutentags(), 0, 0)
endf

fu! s:get_tagfiles_from_gutentags()
	let retval_empty = []
	let [gt_has_data, gtfiles_dict] = s:get_tagfiles_data_from_gutentags()
	if (!gt_has_data) || empty(gtfiles_dict) | retu retval_empty | en

	let skip_empty_lists = s:getcfg_skip_empty_lists()

	for k in s:gutentags_files_tf_keys
		if !has_key(gtfiles_dict, k) | con | en
		unl! expr_val
		let expr_val = get(gtfiles_dict, k)
		if skip_empty_lists && empty(expr_val) | con | en
		" convert to list, if needed
		let expr_type = type(expr_val)
		if expr_type == 1 | retu [ expr_val ] | en
		if expr_type == 3 | retu expr_val | en
		" otherwise, continue to the next dictionary entry
	endfo
	retu retval_empty
endf

" move to a more generic module
fu! s:try_eval(expr, ...)
	try
		retu eval(a:expr)
	cat
		retu a:0 ? a:1 : 0
	endt
endf

fu! s:gettagfiles_on_userbuf() abort
	let skip_empty_lists = s:getcfg_skip_empty_lists()
	" orig: let tfs = get(g:, 'ctrlp_custom_tag_files', tagfiles())
	let tfs = []
	for proc_item in s:get_tagfiles_proclist
		try
			let cond_expr = get(proc_item, 1, '')
			" conditionally decide whether to consider this entry
			"+? if !empty(cond_expr) && !eval(cond_expr) | con | en
			if !empty(cond_expr) && !s:try_eval(cond_expr, 0) | con | en

			let val_expr = proc_item[0]
			unl! val_res
			"? let val_res = eval(val_expr)
			"? sil let val_res = eval(val_expr)
			"? execute 'let val_res = eval(val_expr)'
			let val_res = s:try_eval(val_expr, 0)
			" only consider lists
			if type(val_res) != 3 | con | en
			" conditionally skip empty entries
			if skip_empty_lists && empty(val_res) | con | en
		cat
			con
		endt
		" we reached the end of this block -> keep the value (exit the loop)
		let tfs = val_res
		" TODO: remove from final commit
		" DEBUG: verbose echomsg printf( 'DEBUG: s:gettagfiles_on_userbuf(): val_expr=%s; cond_expr=%s; tfs=%s', string(val_expr), string(cond_expr), string(tfs))
		brea
	endfo

	retu empty(tfs)
		\ ? tfs
		\ : filter(map(tfs, 'fnamemodify(v:val, ":p")'), 'filereadable(v:val)')
endf

fu! s:syntax()
	if !ctrlp#nosy()
		cal ctrlp#hicheck('CtrlPTabExtra', 'Comment')
		sy match CtrlPTabExtra '\zs\t.*\ze$'
	en
endf
" Public {{{1
fu! ctrlp#tag#init()
	let g:ctrlp_alltags = []
	if empty(s:tagfiles) | retu [] | en

	let [tagfiles, tagfiles_seen] = [[], {}]
	for tagfile in s:tagfiles
		if has_key(tagfiles_seen, tagfile) | con | en
		let tagfiles_seen[tagfile] = 1
		cal add(tagfiles, tagfile)

		let alltags = s:filter(ctrlp#utils#readfile(tagfile))
		cal extend(g:ctrlp_alltags, alltags)
	endfo
	let s:tagfiles = tagfiles

	cal s:syntax()
	retu g:ctrlp_alltags
endf

fu! ctrlp#tag#accept(mode, str)
	cal ctrlp#exit()
	let tgaddr = matchstr(a:str, '^[^\t]\+\t\+[^\t]\+\t\zs[^\t]\{-1,}\ze\%(;"\)\?\t')
	let str = matchstr(a:str, '^[^\t]\+\t\+[^\t]\+\ze\t')
	let [tg, fdcnt] = [split(str, '^[^\t]\+\zs\t')[0], s:findcount(str, tgaddr)]
	let cmds = {
		\ 't': ['tab sp', 'tab stj'],
		\ 'h': ['sp', 'stj'],
		\ 'v': ['vs', 'vert stj'],
		\ 'e': ['', 'tj'],
		\ }
	let utg = fdcnt[3] < 2 && fdcnt[0] == 1 && fdcnt[1] == 1
	let cmd = !fdcnt[0] || utg ? cmds[a:mode][0] : cmds[a:mode][1]
	let cmd = a:mode == 'e' && ctrlp#modfilecond(!&aw)
		\ ? ( cmd == 'tj' ? 'stj' : 'sp' ) : cmd
	let cmd = a:mode == 't' ? ctrlp#tabcount().cmd : cmd
	if !fdcnt[0] || utg
		if cmd != ''
			exe cmd
		en
		let save_cst = &cst
		set cst&
		cal feedkeys(":".( utg ? fdcnt[2] : "" )."ta ".tg."\r", 'nt')
		let &cst = save_cst
	el
		let ext = ""
		if fdcnt[1] < 2 && fdcnt[2]
			let [sav_more, &more] = [&more, 0]
			let ext = fdcnt[2]."\r".":let &more = ".sav_more."\r"
		en
		cal feedkeys(":".cmd." ".tg."\r".ext, 'nt')
	en
	cal feedkeys('zvzz', 'nt')
	cal ctrlp#setlcdir()
endf

fu! ctrlp#tag#id()
	retu s:id
endf

fu! ctrlp#tag#enter()
	let s:tagfiles = s:gettagfiles_on_userbuf()
endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
