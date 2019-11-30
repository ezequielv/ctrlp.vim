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

" Vim feature/command/function support {{{1
"? let s:expr_supported_dict = {}

" table with "fixes" for broken detections
let s:supported_expr_localtable = {
	\		':noautocmd': has('autocmd'),
	\ }

fu! ctrlp#utils#make_cmdstr_supported(cmd_list) abort
	" prev: "+ retu join(
	" prev: "+ 	\	filter(
	" prev: "+ 	\		copy(a:cmd_list),
	" prev: "+ 	\		'!empty(v:val) && (exists('':'' . v:val) == 2)'),
	" prev: "+ 	\	' ')
	" prev: retu join(
	" prev: 	\	filter(
	" prev: 	\		copy(a:cmd_list),
	" prev: 	\		'!empty(v:val) && (exists('':'' . substitute(v:val, ''[!]'', '''', ''g'')) == 2)'),
	" prev: 	\	' ')
	"-? let expr_exists = ':' . substitute(v:val, '[!]', '', 'g')
	"-? " TODO: update s:supported_expr_localtable, too
	"-? " prev: retu join(
	"-? " prev: 	\	filter(
	"-? " prev: 	\		copy(a:cmd_list),
	"-? " prev: 	\		'!empty(v:val) && (exists(expr_exists) == 2)'),
	"-? " prev: 	\	' ')
	"-? retu join(
	"-? 	\	filter(
	"-? 	\		copy(a:cmd_list),
	"-? 	\		'!empty(v:val) && ' .
	"-? 	\			'(has_key(s:supported_expr_localtable, expr_exists) ' .
	"-? 	\			'	?	s:supported_expr_localtable[expr_exists] ' .
	"-? 	\			'	:	extend( ' .
	"-? 	\			'			s:supported_expr_localtable, ' .
	"-? 	\			'			{expr_exists: (exists(expr_exists) == 2)} ' .
	"-? 	\			'		)[expr_exists] ' .
	"-? 	\			')'),
	"-? 	\	' ')
	" prev: (at the beginning of outer 'filter()'): \			'!empty(v:val[1]) && ' .
	" NOTE: regex in the "outer" 'filter()': cope with '2match' and user commands
	" NOTE: substitute() in the inner 'map()': allow list elements constisting
	" of commands and parameters, but just check on the first
	" (whitespace-separated) word as the command name.
	retu join(
		\	map(
		\		filter(
		\			map(
		\				filter(
		\					copy(a:cmd_list),
		\					'!empty(v:val)'),
		\				'['':'' . substitute(substitute(v:val, ''[!]'', '''', ''g''), ''\s.*$'', '''', ''''), ' .
		\				' v:val]'),
		\			'(v:val[0] =~# ''\v^:\d*\a[[:alnum:]_]*$'') && ' .
		\				'(has_key(s:supported_expr_localtable, v:val[0]) ' .
		\				'	?	s:supported_expr_localtable[v:val[0]] ' .
		\				'	: (exists(v:val[0]) == 2) ' .
		\				')'),
		\		'v:val[1]'),
		\	' ')
endf

" Buffers and variables {{{1
" FIXME: remove once complete
" NOTE: switching to another and back does reload that buffer if there were no
" other windows with that buffer open, so (for example) local overrides to
" certain options would be lost (I've tested with a vim help document with a
" local override of 'setl nowrap', and calling
" ctrlp#utils#eval_expr_in_buffer() resulted in that buffer "recovering" the
" global value and losing the local override).
let s:eval_expr_in_buffer_use_tabs = !0

	"   done: create a function to evaluate an expression in a buffer, returning
	"   to the previous one.
	"   IDEA: then have ctrlp#utils#getbufvar(bufexp, varname,
	"   type_id_or_string_expr_to_validate_correct_value, defvalue) use that
	"   function.
	"   IDEA: then have ctrlp#utils#getbufchangedtick() call
	"   ctrlp#utils#getbufvar().
fu! ctrlp#utils#eval_expr_in_buffer(bufexp, expr) abort
	" prev: let sav_bufnr = bufnr('%')
	let cur_bufnr = bufnr('%')
	let sav_lazyredraw = &lazyredraw
	let sav_shortmess = &shortmess
	let opts_ui_set = 0
	"+ \	'silent', 'keepalt', 'keepjumps', 'noautocmd', 'hide'])
	"+? \	'silent!', 'keepalt', 'keepjumps', 'noautocmd', 'hide'])
	" TODO: put the body of the option-changing inside a function, and call
	" that instead of having the full body as inline code.
	let cmd_screencommon_prepare =
		\	'if !opts_ui_set | ' .
		\	' if !&lazyredraw | ' .
		\	'  set lazyredraw | ' .
		\	' en | ' .
		\ ' unl! t_s | ' .
		\	' for t_s in filter( ' .
		\	'   ["a", "t", "T", "o", "O", "s", "W", "A", "F"], ' .
		\	'   "stridx(&shortmess, v:val) < 0") | ' .
		\	'  try | exe "set shortmess+=" . t_s | cat | endt | ' .
		\	' endfo | ' .
		\ ' unl! t_s | ' .
		\	' let opts_ui_set=1 | ' .
		\	'en'
	let cmd_screencommon_pref = cmd_screencommon_prepare . ' | '
	if s:eval_expr_in_buffer_use_tabs
		let cmd_tabpagecommon_pref = cmd_screencommon_pref .
			\	ctrlp#utils#make_cmdstr_supported([
			\		'silent', 'keepalt', 'keepjumps', 'noautocmd'])
	el
		let cmd_gotobuf_pref = cmd_screencommon_pref .
			\	ctrlp#utils#make_cmdstr_supported([
			\		'silent', 'keepalt', 'keepjumps', 'noautocmd', 'hide'])
	en
	try
		let dst_bufnr = bufnr(a:bufexp)
		" prev: if dst_bufnr != sav_bufnr
		if dst_bufnr != cur_bufnr
			exe cmd_screencommon_prepare
			if s:eval_expr_in_buffer_use_tabs
				let sav_tabpage = tabpagenr()
				exe cmd_tabpagecommon_pref tabpagenr('$') . 'tab sbuffer' dst_bufnr
			el
				let sav_wincurstate = ctrlp#utils#getwincursorstate()
				let sav_bufnr = cur_bufnr
				" prev: set lazyredraw
				exe cmd_gotobuf_pref 'b' dst_bufnr
			en
		en
		" MAYBE: save and restore cursor position (including relative position
		" with respect to the window top, etc.).
		" NOTE: for now, this expression is evaluated inside the ':h sandbox'.
		sandbox retu eval(a:expr)

	fina
		if exists('sav_tabpage') && (sav_tabpage != tabpagenr())
			" MAYBE: validate that the buffer is the correct one, and/or there is
			" only one window in this tab, etc.
			exe cmd_tabpagecommon_pref 'hide tabclose'
			exe cmd_tabpagecommon_pref 'normal!' sav_tabpage . 'gt'
		en
		" prev: if sav_bufnr != bufnr('%')
		if exists('sav_bufnr') && (sav_bufnr != bufnr('%'))
			if s:eval_expr_in_buffer_use_tabs
				" TODO: raise exception: this should not happen
			el
				" prev: set lazyredraw
				exe cmd_gotobuf_pref 'b' sav_bufnr
			en
		en
		if exists('sav_wincurstate')
			exe cmd_screencommon_prepare
			cal ctrlp#utils#setwincursorstate(sav_wincurstate)
		en
		if &shortmess != sav_shortmess
			let &shortmess = sav_shortmess
		en
		if &lazyredraw != sav_lazyredraw
			let &lazyredraw = sav_lazyredraw
		en
	endt
endf

let s:typeid_num = type(0)
let s:typeid_str = type('')
let s:typeid_list = type([])
let s:typeid_dict = type({})

let s:empty_vals_by_typeid = {
	\		(s:typeid_num): 0,
	\		(s:typeid_str): '',
	\		(s:typeid_list): [],
	\		(s:typeid_dict): {},
	\ }

" NOTE: throws for unsupported typeids.
fu! ctrlp#utils#getemptyval_bytypeid(typid) abort
	retu copy(s:empty_vals_by_typeid[a:typid])
endf

let s:getbufvar_knowntypeidvalidexpr_dict = {
	\		'changedtick': s:typeid_num,
	\ }

" object that can be compared with the 'is'/'isnot' comparison operator.
let s:internal_obj_ref = []

" optional parameters:
"
"		typid_or_validexpr:
"			* if a:typid_or_validexpr is a number ('type()' return value):
"				validate the variable's type against this typeid;
"			* if a:typid_or_validexpr is a string: this is a boolean expression that
"				is to be used to validate that the retrieved value is valid:
"				NOTE: use the empty string for an "always true" shortcut expression,
"				regardless of whether the variable might be known to this function or
"				not;
"				NOTE: use 'v:val' to refer to the value being validated.
"			* if the variable name is "known" to this function (such as
"				'changedtick'): the function behaves as if the caller has specified a
"				suitable type/validation expression and a vim-compatible default.
"
"		default_value:
"			if none of the attempts to retrieve the variable has worked, then this
"			default value will be returned.  No attempt to validate this return
"			valid against 'a:typid_or_validexpr' is made by this function.
"			NOTE: if this parameter is unspecified:
"				* if a:typid_or_validexpr was not specified: it returns the empty
"					string, as per 'getbufvar()'.
"				* if a:typid_or_validexpr is a number ('type()' return value):
"					the empty value as per the typeid (0 for number, '' for strings,
"					etc.);
"				* if a:typid_or_validexpr is an expression: this function raises an
"					exception if it could not retrieve that variable;
" prev: fu! ctrlp#utils#getbufvar(bufexp, varname, typid_or_validexpr, ...) abort
" prev: 	let except_pref = 'ctrlp#utils#getbufvar():'
" prev:
" prev: 	for stage_id in range(2)
" prev: 		unl! val_auto
" prev: 		" prev: let val_auto = (stage_id == 0)
" prev: 		" prev: 	\	?	getbufvar(a:bufexp, a:varname)
" prev: 		" prev: 	\	: ctrlp#utils#eval_expr_in_buffer(a:bufexp, 'b:' . a:varname)
" prev: 		" prev: " validate, in order to detect invalid/absent values.
" prev: 		" prev: if type(a:typid_or_validexpr) == s:typeid_num
" prev: 		" prev: 	let sucflag = (type(val_auto) == a:typid_or_validexpr)
" prev: 		" prev: el
" prev: 		" prev: 	try
" prev: 		" prev: 		" prev: sandbox let sucflag = eval(a:typid_or_validexpr)
" prev: 		" prev: 		sandbox let sucflag = !empty(filter([val_auto], a:typid_or_validexpr))
" prev: 		" prev: 	cat
" prev: 		" prev: 		let sucflag = 0
" prev: 		" prev: 	endt
" prev: 		" prev: en
" prev: 		try
" prev: 			let val_auto = (stage_id == 0)
" prev: 				\	?	getbufvar(a:bufexp, a:varname)
" prev: 				\	: ctrlp#utils#eval_expr_in_buffer(a:bufexp, 'b:' . a:varname)
" prev: 			" validate, in order to detect invalid/absent values.
" prev: 			if type(a:typid_or_validexpr) == s:typeid_num
" prev: 				let sucflag = (type(val_auto) == a:typid_or_validexpr)
" prev: 			el
" prev: 				" prev: sandbox let sucflag = eval(a:typid_or_validexpr)
" prev: 				sandbox let sucflag = !empty(filter([val_auto], a:typid_or_validexpr))
" prev: 			en
" prev:
" prev: 		cat
" prev: 			let sucflag = 0
" prev: 		endt
" prev:
" prev: 		if sucflag | brea | en
" prev: 	endfo
" prev:
" prev: 	if !sucflag
" prev: 		" prev: if (!a:0) && (type(a:typid_or_validexpr) == s:typeid_num)
" prev: 		" prev: 	retu ctrlp#utils#getemptyval_bytypeid(a:typid_or_validexpr)
" prev: 		" prev: elsei a:0
" prev: 		" prev: 	retu a:1
" prev: 		if a:0
" prev: 			retu a:1
" prev: 		elsei (type(a:typid_or_validexpr) == s:typeid_num)
" prev: 			retu ctrlp#utils#getemptyval_bytypeid(a:typid_or_validexpr)
" prev: 		el
" prev: 			throw except_pref . ' invalid/non-existing value and no default provided'
" prev: 		en
" prev: 	en
" prev:
" prev: 	" the value retrieved originally passed the checking criteria: return it.
" prev: 	retu val_auto
" prev: endf
" TEST: unlet! t_vn1 t_s1 t_t1 | let t_vn1='changedtick' | let t_t1='!empty(v:val)' | silent let t_s1 = call('ctrlp#utils#getbufvar', ['#', t_vn1] + (exists('t_t1') ? [t_t1] : []) ) | redraw! | echomsg printf('%s: %s; validator/typeid: %s;', t_vn1, string(t_s1), exists('t_t1') ? string(t_t1) : '<unspecified>') | unlet! t_vn1 t_s1 t_t1
" TEST: unlet! t_vn1 t_s1 t_t1 t_dv1 | let t_vn1='somevar' | let t_t1='' | let t_dv1='my_def' | if exists('t_dv1') && !exists('t_t1') | let t_t1='' | en | silent let t_s1 = call('ctrlp#utils#getbufvar', ['#', t_vn1] + (exists('t_t1') ? [t_t1] + (exists('t_dv1') ? [t_dv1] : []) : []) ) | redraw! | echomsg printf('%s: %s; validator/typeid: %s;', t_vn1, string(t_s1), exists('t_t1') ? string(t_t1) : '<unspecified>') | unlet! t_vn1 t_s1 t_t1 t_dv1
fu! ctrlp#utils#getbufvar(bufexp, varname, ...) abort
	let log_pref = 'ctrlp#utils#getbufvar():'
	let except_pref = log_pref

	let typid_or_validexpr = (a:0 > 0)
		\	? a:1
		\	: get(s:getbufvar_knowntypeidvalidexpr_dict, a:varname, '')
	let validation_is_typeid = type(typid_or_validexpr) == s:typeid_num
	"? let [bufnr_var, bufnr_cur] = [bufnr(a:bufexp), bufnr('%')]
	let bufnr_dst = bufnr(a:bufexp)
	cal ctrlp#ev_log_printf(
		\ '%s entered. a:bufexp=%s; a:varname=%s; a:000=%s; ' .
		\		'bufnr_calculated=%d;',
		\	log_pref, string(a:bufexp), string(a:varname), string(a:000), bufnr_dst)

	" MAYBE: put this inside a function: ctrlp#utils#bufexp_mightbevalid(bufexp)
	let sucflag = (bufnr_dst > 0) && (bufnr_dst <= bufnr('$'))
	if sucflag
		let in_var_buf = bufnr_dst == bufnr('%')
		let varname_as_expr = 'b:' . a:varname
		for use_getbufvar in [1, 0]
			unl! val_any
			try
				let sucflag = 0
				if in_var_buf && !exists(varname_as_expr)
					" we know that we will need to return a default value, if one can be
					" worked out, so there is no point in going through the "get buffer
					" variable" calls.
					brea
				en
				let val_any = use_getbufvar
					\	?	getbufvar(a:bufexp, a:varname)
					\	: ctrlp#utils#eval_expr_in_buffer(
					\			a:bufexp,
					\			in_var_buf
					\				?	varname_as_expr
					\				:	printf(
					\						'exists(%s) ? %s : s:internal_obj_ref',
					\						string(varname_as_expr), varname_as_expr)
					\		)
				" detect an inexisting buffer variable: work out the default value to
				" be returned (outside this 'for' loop).
				if val_any is s:internal_obj_ref | brea | en
				" validate, in order to detect invalid/absent values.
				if validation_is_typeid
					let sucflag = (type(val_any) == typid_or_validexpr)
				" a:typid_or_validexpr unspecified: return whatever was returned by the
				" "get buffer variable" function.
				elsei a:0 == 0
					let sucflag = !0
				" if the caller has specified no validation expression (but no typeid,
				" either), then we can't trust the potentially broken vim
				" 'getbufvar()' function.
				elsei empty(typid_or_validexpr)
					let sucflag = !use_getbufvar
				el
					sandbox let sucflag = !empty(filter([val_any], typid_or_validexpr))
				en

			cat
				cal ctrlp#ev_log_printf(
					\ '%s caught exception when attempting to retrieve the bufvar. ' .
					\		'use_getbufvar=%d; ' .
					\		'exception=%s; throwpoint=%s;',
					\	log_pref, use_getbufvar, string(v:exception), string(v:throwpoint))
				let sucflag = 0
			endt

			if sucflag | brea | en
		endfo
		if sucflag
			cal ctrlp#ev_log_printf(
				\ '%s about to return retrieved value. retval=%s;',
				\	log_pref, string(val_any))
			" the value retrieved originally passed the checking criteria: return it.
			retu val_any
		en
	en

	" return default/throw exception
	if a:0 > 1
		cal ctrlp#ev_log_printf(
			\ '%s about to return caller-specified default value. retval=%s;' .
			\	log_pref, string(a:2))
		retu a:2
	elsei a:0 == 0
		cal ctrlp#ev_log_printf(
			\ '%s about to return standard "var not found" value. retval=%s;',
			\	log_pref, string(''))
		retu ''
	elsei validation_is_typeid
		cal ctrlp#ev_log_printf(
			\ '%s about to default for caller-specified data type. typeid=%d;' .
			\	log_pref, typid_or_validexpr)
		retu ctrlp#utils#getemptyval_bytypeid(typid_or_validexpr)
	el
		" prev: throw except_pref . ' invalid/non-existing value and no default provided'
		let exception_obj = except_pref . ' invalid/non-existing value and no default provided'
		cal ctrlp#ev_log_printf(
			\ '%s about to raise exception. exception=%s;' .
			\	log_pref, string(exception_obj))
		throw exception_obj
	en
endf

" window/cursor state save/restore {{{1
if exists('*getcurpos')
	fu! ctrlp#utils#getcurpos()
		return getcurpos()
	endf
el
	fu! ctrlp#utils#getcurpos()
		return getpos('.')
	endf
en

fu! ctrlp#utils#getwincursorstate()
	let cursor_pos = ctrlp#utils#getcurpos()
	let wincurstate = {
				\ 'cursor_pos': cursor_pos,
				\ }

	sil keepj normal! H0
	let wincurstate.win_h_pos = ctrlp#utils#getcurpos()

	cal setpos('.', cursor_pos)

	return wincurstate
endf

fu! ctrlp#utils#setwincursorstate(wincurstate)
	cal setpos('.', a:wincurstate.win_h_pos)
	sil! normal! zt
	cal setpos('.', a:wincurstate.cursor_pos)
endf

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

" optional args:
" * silent_flag (int (bool), default: true):
"		if "truthy", then errors are ignored.
"		if "falsy", errors are propagated.
fu! ctrlp#utils#mkdir(dir, ...)
	if exists('*mkdir') && !isdirectory(a:dir)
		" TODO: LATER: if a:0 && a:1
		if (!a:0) || a:1
			sil! cal mkdir(a:dir, 'p')
		el
			cal mkdir(a:dir, 'p')
		en
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
		" MAYBE: add detection for the 'rf' value in the 'flags' parameter.
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
