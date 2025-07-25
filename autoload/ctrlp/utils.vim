" =============================================================================
" File:          autoload/ctrlp/utils.vim
" Description:   Utilities
" Author:        Kien Nguyen <github.com/kien>
" =============================================================================

" Static variables {{{1
fu! ctrlp#utils#lash()
	retu &ssl || !exists('+ssl') ? '/' : '\'
endf

fu! ctrlp#utils#lash_for(...)
	retu ( a:0 ? a:1 : getcwd() ) !~ '[\/]$' ? s:lash : ''
endf

if 1
fu! s:lash(...)
	retu call('ctrlp#utils#lash_for', a:000)
endf
elsei 1
" there is a variable with this name already:
"- let s:lash = function('ctrlp#utils#lash_for')
el
fu! s:lash(...)
	retu ( a:0 ? a:1 : getcwd() ) !~ '[\/]$' ? s:lash : ''
endf
en

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
if exists('*abs')
	fu! ctrlp#utils#abs(expr) abort
		retu abs(a:expr)
	endf
el
	" behave as much as 'abs()' as possible
	fu! ctrlp#utils#abs(expr) abort
		let expr_type = type(a:expr)
		if expr_type != 0
			echoe printf(
				\	'ctrlp#utils#abs(): parameter type not supported. ' .
				\		'a:expr=%s; type(a:expr)=%d;',
				\	string(a:expr), expr_type)
			retu -1
		en
		if a:expr < 0
			retu -(a:expr)
		en
		retu a:expr
	endf
en

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

let s:setoptaddremove_opadd_useelem_filterexpr =
	\	'stridx(opt_val_onentry, v:val) < 0'
let s:setoptaddremove_oprem_useelem_filterexpr =
	\	'stridx(opt_val_onentry, v:val) >= 0'

let s:setoptaddremove_opadd_opdict_val =
	\	[ '+=', s:setoptaddremove_opadd_useelem_filterexpr ]
let s:setoptaddremove_oprem_opdict_val =
	\	[ '-=', s:setoptaddremove_oprem_useelem_filterexpr ]

let s:setoptaddremove_op_dict = {
	\		'+=': s:setoptaddremove_opadd_opdict_val,
	\		'-=': s:setoptaddremove_oprem_opdict_val,
	\	}

" prev: " returns:
" prev: "		[changed_value, prev_opt_value]
" prev: fu! ctrlp#utils#set_option_add_flags_cond(opt, flags_str_or_list)
" prev: 	let opt_var = '%' . a:opt
" prev: 	let opt_val_onentry = eval(opt_var)
" prev: 	let flags_list = (type(a:flags_str_or_list) == s:typeid_list)
" prev: 		\	? copy(a:flags_str_or_list)
" prev: 		\	:	split(a:flags_str_or_list, '\zs')
" prev: 	" leave only the flags that were not found in the original option value.
" prev: 	cal filter(flags_list, '(!empty(v:val)) && stridx(opt_var, v:val) < 0')
" prev: 	if empty(flags_list) | retu [0, opt_val_onentry] | en
" prev:
" prev: 	for flag_now in flags_list
" prev: 		try
" prev: 			exe 'set ' . a:opt . '+=' . flag_now
" prev: 		cat
" prev: 			" unsupported value
" prev: 			" MAYBE: log?
" prev: 		endt
" prev: 	endfo
" prev: 	retu [(eval(opt_var) != opt_val_onentry), opt_val_onentry]
" prev: endf

" returns:
"		[changed_value, prev_opt_value]
fu! ctrlp#utils#set_option_addremove_flags_cond(opt, op, flags_str_or_list)
	let log_pref = 'ctrlp#utils#set_option_addremove_flags_cond():'
	let opt_var = '&' . a:opt
	let opt_val_onentry = eval(opt_var)
	let op_entry = s:setoptaddremove_op_dict[a:op]
	let filter_expr = join(
		\	map(
		\		filter(['!empty(v:val)', op_entry[1]], '!empty(v:val)'),
		\		'"(" . v:val . ")"'),
		\	' && ')

	let flags_list = (type(a:flags_str_or_list) == s:typeid_list)
		\	? copy(a:flags_str_or_list)
		\	:	split(a:flags_str_or_list, '\zs')
	" leave only the flags that were not found in the original option value.
	if !empty(filter_expr) | cal filter(flags_list, filter_expr) | en

	cal ctrlp#ev_log_printf(
		\	'%s processing. a:opt=%s; a:op=%s; a:flags_str_or_list=%s; ' .
		\		'opt_var=%s; opt_val_onentry=%s; op_entry=%s; ' .
		\		'filter_expr=%s; flags_list=%s;',
		\	log_pref, string(a:opt), string(a:op), string(a:flags_str_or_list),
		\	string(opt_var), string(opt_val_onentry), string(op_entry),
		\	string(filter_expr), string(flags_list))

	if empty(flags_list) | retu [0, opt_val_onentry] | en

	for flag_now in flags_list
		try
			exe 'set ' . a:opt . op_entry[0] . flag_now
		cat
			" unsupported value
			" MAYBE: log?
		endt
	endfo
	retu [(eval(opt_var) != opt_val_onentry), opt_val_onentry]
endf

"		* opers_flags_list: list of elements of fixed size:
"			each element is made of the parameters to call
"			'ctrlp#utils#set_option_addremove_flags_cond()' with, except the first
"			one, which is 'a:opt', so it's currently:
"			[ op, flags_str_or_list ]
fu! ctrlp#utils#set_option_addremove_flags_opers(opt, opers_flags_list)
	let opt_var = '&' . a:opt
	let opt_val_onentry = eval(opt_var)

	for oper_flags_item in a:opers_flags_list
		cal call(
			\	'ctrlp#utils#set_option_addremove_flags_cond',
			\	[a:opt] + oper_flags_item)
	endfo

	retu [(eval(opt_var) != opt_val_onentry), opt_val_onentry]
endf

fu! ctrlp#utils#set_opt_shortmess_nomessages()
	retu ctrlp#utils#set_option_addremove_flags_opers(
		\	'shortmess',
		\	[
		\		[ '+=', 'atToOsWAF' ],
		\	])
endf

" FIXME: remove once complete
" NOTE: switching to another and back does reload that buffer if there were no
" other windows with that buffer open, so (for example) local overrides to
" certain options would be lost (I've tested with a vim help document with a
" local override of 'setl nowrap', and calling
" ctrlp#utils#eval_expr_in_buffer() resulted in that buffer "recovering" the
" global value and losing the local override).
let s:eval_expr_in_buffer_use_tabs = !0

fu! ctrlp#utils#execute_in_buffer(bufexp, cmd) abort
	let cur_bufnr = bufnr('%')
	let sav_lazyredraw = &lazyredraw
	let opts_ui_set = 0
	let cmd_screencommon_prepare =
		\	'if !opts_ui_set | ' .
		\	' if !&lazyredraw | ' .
		\	'  set lazyredraw | ' .
		\	' en | ' .
		\ ' unl! t_shortmess_rv | ' .
		\	' let t_shortmess_rv = ctrlp#utils#set_opt_shortmess_nomessages() | ' .
		\	' if t_shortmess_rv[0] | let sav_shortmess = t_shortmess_rv[1] | en | ' .
		\ ' unl! t_shortmess_rv | ' .
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
		exe a:cmd
		retu !0

	fina
		if exists('sav_tabpage') && (sav_tabpage != tabpagenr())
			" MAYBE: validate that the buffer is the correct one, and/or there is
			" only one window in this tab, etc.
			exe cmd_tabpagecommon_pref 'hide tabclose'
			exe cmd_tabpagecommon_pref 'normal!' sav_tabpage . 'gt'
		en
		if exists('sav_bufnr') && (sav_bufnr != bufnr('%'))
			if s:eval_expr_in_buffer_use_tabs
				" TODO: raise exception: this should not happen
			el
				exe cmd_gotobuf_pref 'b' sav_bufnr
			en
		en
		if exists('sav_wincurstate')
			exe cmd_screencommon_prepare
			cal ctrlp#utils#setwincursorstate(sav_wincurstate)
		en
		" prev: if &shortmess != sav_shortmess
		if exists('sav_shortmess')
			let &shortmess = sav_shortmess
		en
		if &lazyredraw != sav_lazyredraw
			let &lazyredraw = sav_lazyredraw
		en
	endt
endf

	"   done: create a function to evaluate an expression in a buffer, returning
	"   to the previous one.
	"   IDEA: then have ctrlp#utils#getbufvar(bufexp, varname,
	"   type_id_or_string_expr_to_validate_correct_value, defvalue) use that
	"   function.
	"   IDEA: then have ctrlp#utils#getbufchangedtick() call
	"   ctrlp#utils#getbufvar().
fu! ctrlp#utils#eval_expr_in_buffer(bufexp, expr) abort
	if 1	" FIXME: remove conditional
		retu ctrlp#utils#execute_in_buffer(
			\	a:bufexp,
			\	printf('sandbox retu eval(%s)', string(a:expr)))
	el " FIXME: remove conditional
	" prev: let sav_bufnr = bufnr('%')
	let cur_bufnr = bufnr('%')
	let sav_lazyredraw = &lazyredraw
	" prev: let sav_shortmess = &shortmess
	let opts_ui_set = 0
	"+ \	'silent', 'keepalt', 'keepjumps', 'noautocmd', 'hide'])
	"+? \	'silent!', 'keepalt', 'keepjumps', 'noautocmd', 'hide'])
	" TODO: put the body of the option-changing inside a function, and call
	" that instead of having the full body as inline code.
	" prev: \ ' unl! t_s | ' .
	" prev: \	' for t_s in filter( ' .
	" prev: \	'   ["a", "t", "T", "o", "O", "s", "W", "A", "F"], ' .
	" prev: \	'   "stridx(&shortmess, v:val) < 0") | ' .
	" prev: \	'  try | exe "set shortmess+=" . t_s | cat | endt | ' .
	" prev: \	' endfo | ' .
	" prev: \ ' unl! t_s | ' .
	let cmd_screencommon_prepare =
		\	'if !opts_ui_set | ' .
		\	' if !&lazyredraw | ' .
		\	'  set lazyredraw | ' .
		\	' en | ' .
		\ ' unl! t_shortmess_rv | ' .
		\	' let t_shortmess_rv = ctrlp#utils#set_opt_shortmess_nomessages() | ' .
		\	' if t_shortmess_rv[0] | let sav_shortmess = t_shortmess_rv[1] | en | ' .
		\ ' unl! t_shortmess_rv | ' .
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
		" prev: if &shortmess != sav_shortmess
		if exists('sav_shortmess')
			let &shortmess = sav_shortmess
		en
		if &lazyredraw != sav_lazyredraw
			let &lazyredraw = sav_lazyredraw
		en
	endt
	en " FIXME: remove conditional
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
		" handle "variable" names with prefixes: '&', '&l:': use the provided
		" a:varname as it is.
		" prev: let varname_as_expr = 'b:' . a:varname
		let varname_as_expr =
			\	( (a:varname =~# '\v^\&%(l:)?') ?	'' : 'b:' ) . a:varname
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

fu! s:restore_vals_helper()
	let except_pref = 's:restore_vals_helper():'
	if !exists('s:restore_vals_last_restoreinfo_list')
		th printf('%s required pre-condition has not been met', except_pref)
	en
	let num_restored = 0
	for [restoreinfo_var, restoreinfo_val] in s:restore_vals_last_restoreinfo_list
		try
			" prev: if exists(restoreinfo_var) && (eval(restoreinfo_var) !=# restoreinfo_val)
			if exists(restoreinfo_var)
				unl! restoreinfo_val_prev
				let restoreinfo_val_prev = eval(restoreinfo_var)
				if restoreinfo_val_prev ==# restoreinfo_val | con | en
				" prev: if restoreinfo_val_prev !=# restoreinfo_val
					if type(restoreinfo_val_prev) != type(restoreinfo_val)
						unl {restoreinfo_var}
					en
				" prev: en
			en
			let {restoreinfo_var} = restoreinfo_val
			let num_restored += 1

		"? cat
		"? 	" TODO: save first exception, count exceptions
		endt
	endfo
	" TODO: re-throw the first exception, report counter (TODO: there's an
	" example of this in some ctrlp module (mine))
	
	retu num_restored
endf

fu! s:detect_getbufvar_support() abort
	if exists('s:getbufvar_supports_def') | retu s:getbufvar_supports_def | en
	let bufexpr = bufnr('%')
	if bufexpr > 0
		for varname in ['nonexisting_variable_1234567890']
			if exists('b:' . varname) | con | en
			try
				" NOTE: this function signature is not available on vim-7.0, so we
				" will attempt to detect its support here.
				let getbufvar_supports_def = getbufvar(
					\	bufexpr, varname, s:internal_obj_ref) is s:internal_obj_ref
			cat
				let getbufvar_supports_def = 0
			endt
			let s:getbufvar_supports_def = getbufvar_supports_def
			"+? retu s:getbufvar_supports_def
		endfo
		" if none of our varname values was good for feature detection, we will
		" fallback to the most compatible case.
	en
	" prev: " prev: let getbufvar_supports_def = 0
	" prev: let s:getbufvar_supports_def = 0
	if !exists('s:getbufvar_supports_def')
		let s:getbufvar_supports_def = 0
	en
	retu s:getbufvar_supports_def
endf

fu! ctrlp#utils#restore_vals_in_buf(bufexpr, restoreinfo_list)
	if empty(a:restoreinfo_list) | retu 0 | en

	let bufnr = bufnr(a:bufexpr)
	" prev: let filter_expr_varprocremote =
	" prev: 	\	'v:val[0] =~# ''\v^\&%([lg]:)?[a-z][[:alnum:]_]*$'''
	" MAYBE: use: 'if s:getbufvar_supports_def', and
	"  do a 'cal s:detect_getbufvar_support()' above.
	if s:detect_getbufvar_support()
		let opts_remote_list = a:restoreinfo_list
		let opts_inbuf_list = []
	el
		let filter_expr_varprocremote =
			\	'v:val[0] =~# ''\v^\&%([lg]:)?[a-z][[:alnum:]_]*$'''
		" split the input list into two groups:
		" vim options can be read and written to using 'getbufvar()' and
		" 'setbufvar()', respectively.
		let opts_remote_list = filter(
			\	copy(a:restoreinfo_list),
			\	filter_expr_varprocremote)
		let opts_inbuf_list = filter(
			\	copy(a:restoreinfo_list),
			\	printf('!(%s)', filter_expr_varprocremote))
	en

	let num_restored = 0

	if !empty(opts_remote_list)
		" use getbufvar(), setbufvar()
		for [restoreinfo_var, restoreinfo_val] in opts_remote_list
			try
				" prev: let varname_mangled = substitute(
				" prev: 	\	restoreinfo_var, '\v^\&\zs%([[:alpha:]]:)', '', '')
				let varname_mangled = substitute(
					\	restoreinfo_var, '\v^%(\&)?\zs%([[:alpha:]]:)', '', '')
				" TODO: also deal with different types (':unlet', etc.)
				if s:getbufvar_supports_def
					unl! varval
					let varval = getbufvar(bufnr, varname_mangled, s:internal_obj_ref)
					let procflag = (varval is s:internal_obj_ref)
						\	|| (varval !=# restoreinfo_val)
					unl varval
				el
					let procflag = getbufvar(bufnr, varname_mangled) !=# restoreinfo_val
				en
				" prev: if getbufvar(bufnr, restoreinfo_var) !=# restoreinfo_val
				if procflag
					cal setbufvar(bufnr, varname_mangled, restoreinfo_val)
					let num_restored += 1
				en

			"? cat
			"? 	" TODO: save first exception, count exceptions
			endt
		endfo
		" TODO: re-throw the first exception, report counter (TODO: there's an
		" example of this in some ctrlp module (mine))
	en

	if !empty(opts_inbuf_list)
		try
			" no need to copy, as this is a read-only list for us.
			let s:restore_vals_last_restoreinfo_list = opts_inbuf_list
			let num_restored += ctrlp#utils#execute_in_buffer(
				\	bufnr, 'retu s:restore_vals_helper()')
		fina
			unl! s:restore_vals_last_restoreinfo_list
		endt
	en

	retu num_restored
endf

" regex support {{{1

fu! ctrlp#utils#regex_literal2regex_nomagic(str)
	retu escape(a:str, '^$\')
endf

" window/cursor state save/restore {{{1
if exists('*getcurpos')
	fu! ctrlp#utils#getcurpos() abort
		return getcurpos()
	endf
el
	fu! ctrlp#utils#getcurpos() abort
		return getpos('.')
	endf
en

" TODO: use winsaveview(), winrestview() inside/instead these functions.
fu! ctrlp#utils#getwincursorstate() abort
	let cursor_pos = ctrlp#utils#getcurpos()
	let wincurstate = {
				\ 'cursor_pos': cursor_pos,
				\ }

	sil keepj normal! H0
	let wincurstate.win_h_pos = ctrlp#utils#getcurpos()

	cal setpos('.', cursor_pos)

	return wincurstate
endf

fu! ctrlp#utils#setwincursorstate(wincurstate) abort
	cal setpos('.', a:wincurstate.win_h_pos)
	sil! normal! zt
	cal setpos('.', a:wincurstate.cursor_pos)
endf

" optional args:
"		* tabpageexpr:
"			* if ommitted or 0, it retrieves the current tabpagenr().
"			* '$': get the last tabpage (tabpagenr('$')).
"			* if it's a valid tabpagenr() (number), return that value.
"			* NOTE: exceptions are thrown for unsupported/invalid values.
fu! ctrlp#utils#gettabpagenr(...) abort
	" prev: let tabpagenr_args =
	" prev: 	\	(!a:0) || ( (type(a:1) == s:typeid_num) && (a:1 == 0) )
	" prev: 	\	?	[] : [a:1]
	" prev: retu call('tabpagenr', tabpagenr_args)
	if a:0
		if type(a:1) == s:typeid_num
			if a:1 == 0
				" prev: retu tabpagenr()
				" fall through
			elsei (a:1 >= 1) && (a:1 <= tabpagenr('$'))
				retu a:1
			el
				throw printf('%s invalid tabpagenr=%s', except_pref, string(a:1))
			en
			" fall through
		el
			" let this function return an error for invalid expressions.
			retu tabpagenr(a:1)
		en
		" prev: throw printf('%s invalid tabpagenr=%s', except_pref, string(a:1))
		" fall through
	en
	retu tabpagenr()
endf

let s:gettablayoutinfo_switchtab_cmd_pref = ctrlp#utils#make_cmdstr_supported([
	\		'noautocmd', 'keepjumps',
	\	])

" TODO: continue...: fu! ctrlp#utils#gettabwin... (position in the editor's complete layout -- including bufnr?)
" TODO: document the dictionary elements that are guaranteed to be stable.
" optional args:
"		* tabpageexpr: see ctrlp#utils#gettabpagenr()
fu! ctrlp#utils#gettablayoutsnapshot(...) abort
	" pass the first optional argument (if there is one) to the invoked function
	let info_tabpagenr = call('ctrlp#utils#gettabpagenr', a:000[:0])

	let cur_tabpagenr = tabpagenr()
	let winnr_focused = tabpagewinnr(info_tabpagenr)
	let buflist = tabpagebuflist(info_tabpagenr)

	let tablayout_dict = {
		\		'tabpagenr': info_tabpagenr,
		\		'winnr_cnt': tabpagewinnr(info_tabpagenr, '$'),
		\		'winnr_focused': winnr_focused,
		\		'bufnr_all': buflist,
		\		'bufnr_focused': buflist[winnr_focused - 1],
		\		'lines_term': &lines,
		\	}

	try
		if cur_tabpagenr != info_tabpagenr
			exe s:gettablayoutinfo_switchtab_cmd_pref 'normal!' info_tabpagenr . 'gt'
		en
		let tablayout_dict['winview_focused'] = winsaveview()
		let tablayout_dict['winrestcmd'] = winrestcmd()
	fina
		if cur_tabpagenr != tabpagenr()
			exe s:gettablayoutinfo_switchtab_cmd_pref 'normal!' cur_tabpagenr . 'gt'
		en
	endt

	retu tablayout_dict
endf

let s:tablayoutsnapshot_comp_part_nonactivebufs = [
	\		'bufnr_all',
	\	]
let s:tablayoutsnapshot_comp_part_cursorstate = [
	\		'winview_focused',
	\	]
let s:tablayoutsnapshot_comp_part_tabwinsizes = [
	\		'winrestcmd',
	\		'lines_term',
	\	]

let s:tablayoutsnapshot_comp_presets = {
	\		'tablysnapcomp_samewinfocused': [
	\				'bufnr_focused',
	\			]
	\			+ s:tablayoutsnapshot_comp_part_cursorstate
	\			+ s:tablayoutsnapshot_comp_part_nonactivebufs
	\			+ s:tablayoutsnapshot_comp_part_tabwinsizes
	\			,
	\		'tablysnapcomp_samewincnt': [
	\				'bufnr_focused',
	\				'winnr_focused',
	\			]
	\			+ s:tablayoutsnapshot_comp_part_cursorstate
	\			+ s:tablayoutsnapshot_comp_part_nonactivebufs
	\			+ s:tablayoutsnapshot_comp_part_tabwinsizes
	\			,
	\	}

" optional args:
"		* kwargs (dictionary):
"			* 'tabpageexpr': see ctrlp#utils#gettabpagenr();
"			* 'tablayoutsnapshot_new': if not specified, gets it by calling
"				'ctrlp#utils#gettablayoutsnapshot(kwargs['tabpageexpr'])';
"			* 'ignored_fields': fields that are not used in the comparison;
fu! ctrlp#utils#istablayoutsnapshotsame(tablayoutsnapshot_prev, ...) abort
	let except_pref = 'ctrlp#utils#istablayoutsnapshotsame():'
	let kwargs = a:0 ? a:1 : {}
	let tablayout_prev = copy(a:tablayoutsnapshot_prev)
	let tablayout_new = has_key(kwargs, 'tablayoutsnapshot_new')
		\	? deepcopy(kwargs['tablayoutsnapshot_new'])
		\	: ctrlp#utils#gettablayoutsnapshot(get(kwargs, 'tabpageexpr', 0))
	" support keywords in 'ignored_fields', so that we can populate the list
	" using a number of presets whose actual definitions are hidden from the
	" caller.
	let ignored_fields_any = get(kwargs, 'ignored_fields', s:internal_obj_ref)
	if ignored_fields_any is s:internal_obj_ref
		let ignored_fields_list = []
	el
		let ignored_fields_any_type = type(ignored_fields_any)
		if ignored_fields_any_type == s:typeid_str
			" let this function throw an exception if the key is not found in the
			" dictionary.
			let ignored_fields_list =
				\	s:tablayoutsnapshot_comp_presets[ignored_fields_any]
		elsei ignored_fields_any_type == s:typeid_list
			let ignored_fields_list = ignored_fields_any
		else
			throw printf(
				\	'%s unsupported value type in kwargs[%s]: type=%d; value=%s;',
				\	except_pref, 'ignored_fields',
				\	ignored_fields_any_type, string(ignored_fields_any))
		en
	en
	unl! ignored_fields_any ignored_fields_any_type

	" filter 'tablayout_prev', 'tablayout_new' using 'ignored_fields_list'.
	if !empty(ignored_fields_list)
		for tablayout_obj in [tablayout_prev, tablayout_new]
			cal filter(tablayout_obj, 'index(ignored_fields_list, v:key) < 0')
		endfo
	en

	try
		retu tablayout_prev == tablayout_new
	cat
		retu 0
	endt
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

let s:bufname_is_vim_notyetnamed_regex =
	\	'\v[\/]?\[(\d+\*)?No Name\]$'

let s:pathname_is_abs_path_regex =
	\	(has('win32') || has('win64'))
	\	?	'\v^([a-zA-Z]:){-}[/\\]'
	\	: '\v^[/\\]'

fu! ctrlp#utils#bufname_is_pathname(path) abort
	retu (!empty(a:path))
		\	&& (a:path !~# s:bufname_is_vim_notyetnamed_regex)
		\	&& (!ctrlp#utils#fname_is_virtual(a:path))
endf

" optional args:
"		* do_full_check (bool, default: false)
fu! ctrlp#utils#pathname_is_abs(path, ...) abort
	" prev: \	( (a:0 && a:1) ? (!ctrlp#utils#fname_is_virtual(a:path)) : !0 )
	let retval =
		\	( (!(a:0 && a:1)) || ctrlp#utils#bufname_is_pathname(a:path) )
		\	&&
		\	(a:path =~# s:pathname_is_abs_path_regex)
	retu retval
endf

" optional args:
"		* do_full_check (bool, default: false)
fu! ctrlp#utils#pathname_is_rel(path, ...) abort
	" prev: \	( (a:0 && a:1) ? (!ctrlp#utils#fname_is_virtual(a:path)) : !0 )
	let retval =
		\	( (!(a:0 && a:1)) || ctrlp#utils#bufname_is_pathname(a:path) )
		\	&&
		\	(a:path !~# s:pathname_is_abs_path_regex)
	retu retval
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
