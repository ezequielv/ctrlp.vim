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
" return value:
"  list of 4 elements:
"   #0: whether there would be a search/select operation needed
"       (for tags that only had 0 (no match) or 1 (single match), this would
"       be zero, for tags that had >= 2 matches, this will be 1).
"   when return_value[0] is zero:
"    #1: 0
"    #2: 0
"    #3: 0
"   when return_value[0] is non-zero:
"    #1:
"     if non-zero: the tag entries only matched against the "leaf" filename,
"                  and we could not find a match for the exact filename and/or
"                  the specified "ex" command to locate the tag;
"     if zero:     there are non-"fuzzy"/inexact matches.  This does not imply
"                  that there were "exact" matches at all, though.
"    #2: list index (+1) of the last match in the calculated (re-arranged)
"        matched tag entries list.
"        NOTE: this re-arranged list is made of (in order):
"         * entries that are present in the current buffer ('%');
"         * entries that are present in other buffers/files;
"        if this is zero, then that means that there no matches at all.
"    #3: len(tag_entries_for_the_selected_symbol_not_considering_the_whole_selected_entry),
"        which can be zero if no entries for the selected identifier have been
"        found in the current buffer ('%').
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
		cal ctrlp#ev_log_printf(
			\ 's:gettagfiles_on_userbuf(): val_expr=%s; cond_expr=%s; tfs=%s',
			\	string(val_expr), string(cond_expr), string(tfs))
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

let s:impl_select_new = 1

if s:impl_select_new

fu! s:source_name_canonicalize(fname)
	retu simplify(fnamemodify(a:fname, ':p'))
endf

fu! s:tagfiles_listorstr_to_str(tf_val)
	let tf_type = type(a:tf_val)
	if tf_type == 1 | retu a:tf_val | en
	" MAYBE: throw error instead?
	if tf_type != 3 | retu '' | en
	retu join(map(copy(a:tf_val), 'escape(v:val, ''\,'')'), ',')
endf

" optional args:
"  tags_val_flagorval:
"   if it's a list: use this list for the tagfiles
"   otherwise, use 's:tagfiles' (if "truthy"), or
"   do not modify the &l:tags at all (if "falsy").
fu! s:get_taglist_result(tg, ofname, tgaddr, ...)
	let log_pref = 's:get_taglist_result():'
	let retval_notfound = {}
	let fname = s:source_name_canonicalize(a:ofname)

	cal ctrlp#ev_log_printf(
		\	'%s entered. tag=%s; filename_orig=%s; tgaddr=%s; ' .
		\		'fname_canon=%s; cwd=%s;',
		\	log_pref, string(a:tg), string(a:ofname), string(a:tgaddr),
		\		string(fname), string(getcwd()))

	" whichever this buffer is, we'll set a buffer-local variable to make vim
	" search in s:tagfiles
	try
		let tags_val_flagorval = get(a:000, 0, !0)
		let tags_val_flagorval_type = type(tags_val_flagorval)
		" prev: let [&l:tags, sav_tags] = [s:tagfiles, &l:tags]
		if (tags_val_flagorval_type == 3) || (!!tags_val_flagorval)
			let sav_tags = &l:tags
			let &l:tags = s:tagfiles_listorstr_to_str(
				\ (tags_val_flagorval_type == 3) ? tags_val_flagorval_type : s:tagfiles)
		en
		" match full identifiers only
		let taglist_res = taglist('^'.a:tg.'$')
		" TODO: remove from final commit
		cal ctrlp#ev_log_printf(
			\	'%s about to process taglist() result. ' .
			\	'tag=%s; len(result)=%d; tagfiles()=%s;',
			\ log_pref,
			\	string(a:tg), len(taglist_res), string(tagfiles()))
		if empty(taglist_res) | retu retval_notfound | en
		let has_tgaddr = !empty(a:tgaddr)
		let [match_index, idx] = [-1, -1]
		" IDEA: store the result of the matching expression in a list of the same
		" length, then find the first (or all of) that has the value 1 (!!0).
		"  IDEA: let matched_res = map(copy(taglist_res),
		"   '(s:source_name_canonicalize(v:val[''filename''] == fname) && ' .
		"   '(!has_tgaddr || (v:val['cmd'] ==# a:tgaddr))'
		"   IDEA: first_match_index = index(matched_res, !!0) # could be -1 if no matches
		" find an exact match first
		for taglist_entry in taglist_res
			let idx += 1
			" TODO: remove from final commit
			cal ctrlp#ev_log_printf(
				\	'%s about to process taglist() result entry. ' .
				\	'entry: %s;', log_pref, string(taglist_entry))
			if s:source_name_canonicalize(taglist_entry['filename']) !=# fname
				cal ctrlp#ev_log_printf(
					\	'%s  skipping entry: entry filename does not match the expected value',
					\	log_pref)
				con
			en
			if has_tgaddr && (taglist_entry['cmd'] !=# a:tgaddr)
				cal ctrlp#ev_log_printf(
					\	'%s  skipping entry: entry command does not match the expected value',
					\	log_pref)
				con
			en
			let match_index = idx
			brea
		endfo
		if match_index < 0 | retu retval_notfound | en

		let retval = {
			\		'taglist_entry': taglist_res[match_index],
			\		'match_number': (match_index + 1),
			\	}
		if exists('sav_tags')
			"-? " prev: ... = copy(&l:tags) # wrong?
			let retval['tagfiles'] = tagfiles()
		en
		retu retval

	fina
		if exists('sav_tags') | let &l:tags = sav_tags | en
	endt
endf

let s:has_jumplist = has('jumplist')
let s:has_keeppatterns_cmd = exists(':keeppatterns')
let s:cmdname_keeppatterns = s:has_keeppatterns_cmd ? 'keeppatterns' : ''
"? " TODO: TESTING: let s:has_jumplist = 0

" completely new rewrite(s)
fu! ctrlp#tag#accept(mode, str)
	" NOTE: as we're not doing ctrlp#exit() anymore at the beginning, we can
	" assume that the 'CtrlP' window might be current.
	" prev: cal ctrlp#exit()

	let tgaddr = matchstr(a:str, '^[^\t]\+\t\+[^\t]\+\t\zs[^\t]\{-1,}\ze\%(;"\)\?\t')
	" MAYBE: improve the extraction of tg, ofname and tgaddr from a:str
	let tag_and_name = matchstr(a:str, '^[^\t]\+\t\+[^\t]\+\ze\t')
	let [tg, ofname] = split(tag_and_name, '\t\+\ze[^\t]\+$')
	let fname = s:source_name_canonicalize(ofname)

	cal ctrlp#ev_log_printf(
		\	'ctrlp#tag#accept(mode, str): entered. ' .
		\		'mode=%s; str=%s; ' .
		\		'tgaddr=%s; tag=%s; filename_orig=%s; filename_canon=%s',
		\	string(a:mode), string(a:str),
		\		string(tgaddr), string(tg),
		\		string(ofname), string(fname))
	" FIXME: think hard how to use the 'tagstack' (if the option is available
	" and enabled) naturally, without second-guessing what 'vim' might be doing
	" (which is version and implementation dependant, and possibly
	" option-configurable).

	" MAYBE: IDEA: would this work?
	" * (config-variable optional) check whether the tag would be found by vim:
	"  * call s:get_taglist_result() before doing anything else;
	"   * if it failed, we could display an error message (ctrlp function? which
	"     one?);
	" . save current (non-'ControlP') buffer and position:
	"  * MAYBE: see 's:getenv()' in 'autoload/ctlrp.vim';
	"   * TODO: expose certain members from the 's:' variables retrieved in
	"   's:getenv()':
	"			* s:crword, s:crnbword, s:crgfile, s:crline, s:crcursor, s:crbufnr,
	"			  s:cwd, s:crfile, s:crfpath;
	"  * fallback: 'enter' ext func;
	let env_dict = copy(ctrlp#get_last_invocation_env())

	" . save copy(s:tagfiles) in a local variable;
	"? let [sav_local_tagfiles, sav_hidden] = [copy(s:tagfiles), &hidden]
	let sav_local_tagfiles = copy(s:tagfiles)

	" * ctrlp#acceptfile(mode, tagfile) to switch/open to the correct
	"   tab/window/buffer;
	" MAYBE: use a path relative to either the current (before entering
	" 'ControlP')) buffer, the tagfile being used, or something else.
	"-? verbose echomsg printf(
	"-? 	\		'DEBUG: about to: ctrlp#acceptfile(%s, %s)',
	"-? 	\		string(a:mode), string(env_dict['crfile']))
	"-? cal ctrlp#acceptfile(a:mode, env_dict['crfile'])
	" TODO: remove from final commit
	cal ctrlp#ev_log_printf(
		\		'ctrlp#tag#accept(): about to: ctrlp#acceptfile(%s, %s)',
		\		string(a:mode), string(fname))
	"? cal ctrlp#acceptfile(a:mode, fname)
	keepjumps cal ctrlp#acceptfile(a:mode, fname)
	" TODO: remove from final commit
	cal ctrlp#ev_log_printf('after ctrlp#acceptfile()')

	let [sav_bufnr, sav_cpos] = [bufnr('%'), getpos('.')]
	let cmd_setpos_pref = 'keepalt noautocmd keepjumps hide '
	let tagcmd_bufnr = env_dict['crbufnr']
	try
		" . 'set hidden' (so we can switch away from that buffer if necessary);
		"		(NOTE: we'll use the ':hide' command instead)
		" * go back to the saved buffer and position;
		"  * NOTE: use ':hid[e]'
		"  * MAYBE: 'keepjumps'? (keepj)
		"  * MAYBE: 'noautocmd'? (noa)
		"  * MAYBE: 'keepalt'? (keepa)
		" TODO: remove from final commit
		cal ctrlp#ev_log_printf('about to switch to buffer')
		" FIXME: determine whether the 'keepjumps' should be added or not, based
		" on whether the buffer containing the tag definition is the same as the
		" "current" one (the one we are jumping from) or not.  This will also have
		" an implication on whether there should be a 'keepjumps' on the following
		" command(s) or not.
		let cmd_buffer_pref = 'keepalt noautocmd keepjumps hide'
		exe cmd_buffer_pref 'b' tagcmd_bufnr
		" TODO: remove from final commit
		cal ctrlp#ev_log_printf('about to call setpos()')
		keepalt noautocmd keepjumps hide cal setpos('.', env_dict['crcursor'])

		" * save the &l:tags and the bufnr() (which we probably already have in
		"   the "save current buffer and position" step, above).
		let sav_tags = &l:tags

		" * set &l:tags to the saved s:tagfiles (which might have been cleared by
		"   ctrlp#exit() and friends, so we don't depend on that variable not
		"   having been cleared).
		let &l:tags = s:tagfiles_listorstr_to_str(sav_local_tagfiles)

		" * call s:get_taglist_result() to work out the parameters to the ':tag'
		"   command;
		let taglist_find_result = s:get_taglist_result(tg, fname, tgaddr)

		" TODO: remove from final commit
		cal ctrlp#ev_log_printf(
			\		'tag: %s; bufnr=%d; fname=%s; match_number=%s; ' .
			\		'taglist_entry=%s; tagfiles=%s;',
			\		string(tg), bufnr('%'), string(fname),
			\		get(taglist_find_result, 'match_number', '<not_found>'),
			\		string(get(taglist_find_result, 'taglist_entry', '<not_found>')),
			\		string(&l:tags))

		" NOTE: for this command, we want to keep the 'jumplist', update (if vim
		" deems that necessary) the 'tagstack', but still keep the "alternate
		" file" intact, and not trigger autocmds (as we did not run those when
		" leaving this buffer before).
		"? let taglist_entry = taglist_find_result['taglist_entry']
		" TODO: find out the right 'escape()'-like function or 'escape()'
		" expression to specify the correct parameters to the ':tag' command.
		"+? let cmd_tagorjmp_pref = 'keepalt noautocmd hide '
		let cmd_tagorjmp_pref = 'keepalt noautocmd keepjumps hide '

		" prev: " NOTE: we are signalling to the 'finally' block that we're happy to stay
		" prev: " where we are in this (potentially) new file.
		" prev: " NOTE: we leave sav_tags alone, so we can restore its previous value.
		" prev: " NOTE: for now, we will stay in this new buffer if we've switched to it
		" prev: " before trying to get to the tag definition.
		" prev: if sav_bufnr != tagcmd_bufnr
		" prev: 	unlet! sav_cpos sav_bufnr
		" prev: en

		" FIXME: on vim-7.0 (and maybe other early versions?), the tagselect()
		" returns paths that aren't accessible from the 'getcwd()' directory, thus
		" making it (nearly?) impossible to accurately determine if there was an
		" actual tag match that matches the line buffer that has been parsed in
		" this function (passed as 'tg, fname, tgaddr' above).
		" prev: if empty(taglist_find_result) | retu | en
		if empty(taglist_find_result)
			" NOTE: if this address is not found, then we'll let vim report it as
			" normal.  Example:
			"  E486: Pattern not found: stringnotfound_madeup
			" NOTE: see ':h tag-search'
			let sav_magic = &magic
			set nomagic

			exe cmd_buffer_pref 'b' sav_bufnr

			" optionally position the cursor in a good location to to the search
			" manually.
			if tgaddr =~# '\v^[/\?]'
				exe 'keepjumps ' . ( ( tgaddr[0] ==# '/' ) ? '1' : '$' )
			elsei tgaddr =~# '\v^\d+$'
				" no more positioning would be needed, we're letting the line number
				" command leave the cursor where vim normally decides to.
			el
				exe cmd_setpos_pref . 'cal setpos(''.'', sav_cpos)'
			en
			" prev: exe cmd_tagorjmp_pref . 'keeppatterns sandbox ' . substitute(tgaddr, '\v[/\?]$', '', '')
			" prev: let cmd_last = cmd_tagorjmp_pref . 'keeppatterns sandbox ' . substitute(tgaddr, '\v[/\?]$', '', '')
			let cmd_last = cmd_tagorjmp_pref . s:cmdname_keeppatterns . ' sandbox ' . substitute(tgaddr, '\v[/\?]$', '', '')
			cal ctrlp#ev_log_printf(
				\		'ctrlp#tag#accept(): about to execute ex command: %s ' .
				\			'on bufnr=%d (bufname=%s)',
				\		string(cmd_last), bufnr(0), string(bufname('%'))
				\	)
			exe cmd_last
		el
			" prev: cal ctrlp#ev_log_printf(
			" prev: 	\		'tag: %s; bufnr=%d; fname=%s; match_number=%d; ' .
			" prev: 	\		'taglist_entry=%s; tagfiles=%s;',
			" prev: 	\		string(tg), bufnr('%'), string(fname),
			" prev: 	\		taglist_find_result['match_number'],
			" prev: 	\		string(taglist_find_result['taglist_entry']),
			" prev: 	\		string(&l:tags))

			" NOTE: we are signalling to the 'finally' block that we're happy to
			" stay where we are in this (potentially) new file.
			" NOTE: we leave sav_tags alone, so we can restore its previous value.
			" NOTE: for now, we will stay in this new buffer if we've switched to it
			" before trying to get to the tag definition.
			if sav_bufnr != tagcmd_bufnr
				unlet! sav_cpos sav_bufnr
			en

			" * execute the ':tag' command;
			"  * note: this will update the jumplist and the tagstack, as you'd
			"    expect;
			" prev: " NOTE: for this command, we want to keep the 'jumplist', update (if vim
			" prev: " deems that necessary) the 'tagstack', but still keep the "alternate
			" prev: " file" intact, and not trigger autocmds (as we did not run those when
			" prev: " leaving this buffer before).
			" prev: "? let taglist_entry = taglist_find_result['taglist_entry']
			" prev: " TODO: find out the right 'escape()'-like function or 'escape()'
			" prev: " expression to specify the correct parameters to the ':tag' command.
			" prev: exe 'keepalt noautocmd hide' taglist_find_result['match_number']
			" prev: 	\	'tag' escape(tg, ' "\')
			" TODO: find out the right 'escape()'-like function or 'escape()'
			" expression to specify the correct parameters to the ':tag' command.
			exe cmd_tagorjmp_pref . taglist_find_result['match_number']
				\	'tag' escape(tg, ' "\')
		en

		" NOTE: we leave sav_tags alone, so we can restore its previous value.
		unlet! sav_cpos sav_bufnr

	fina
		" + restore the 'hidden' setting (using ':hide' now);
		" . restore the "bufvar" for the buffer from which we executed the ':tag'
		"   command (which could still be the same as the one that the ':tag'
		"   command navigated to);
		if exists('sav_magic')
			let &magic = sav_magic
		en
		if exists('sav_tags')
			cal setbufvar(tagcmd_bufnr, '&tags', sav_tags)
		en
		if exists('sav_bufnr')
			exe cmd_buffer_pref 'b' sav_bufnr
		en
		if exists('sav_cpos')
			" prev: keepalt noautocmd keepjumps hide cal setpos('.', sav_cpos)
			exe cmd_setpos_pref . 'cal setpos(''.'', sav_cpos)'
		en
	endt
endf

en " s:impl_select_new

fu! ctrlp#tag#id()
	retu s:id
endf

fu! ctrlp#tag#enter()
	let s:tagfiles = s:gettagfiles_on_userbuf()
endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
