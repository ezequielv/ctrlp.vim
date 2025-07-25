" =============================================================================
" File:          autoload/ctrlp/tagutils.vim
" Description:   Tag files management - common utilities
" Author:        Ezequiel Valenzuela <github.com/ezequielv>
" =============================================================================

" Global Settings {{{1

if get(g:, 'ctrlp_tagutils_loaded', 0)
	finish
en
let g:ctrlp_tagutils_loaded = 1

" }}}
" Initialization {{{1

" to be used in calls to 'ctrlp#tmpfm#*()' functions.
let s:tmpfm_myid = 'tagutils'

let s:typeid_num = type(0)
let s:typeid_str = type('')
let s:typeid_list = type([])
let s:typeid_dict = type({})

let s:internal_obj_ref = []

" }}}
" Internals {{{1

"? fu! s:validate_value_in_list(val, allowed_values)
"? endf

"? " prev: 'noautocmd', 
"? " prev: 'keepjumps',
"? let s:gettablayoutinfo_switchtoorigbuf_cmd_pref =
"? 	\	ctrlp#utils#make_cmdstr_supported([
"? 	\	])

let s:accepttag_movetobufcur_nojumps_cmd_pref =
	\	ctrlp#utils#make_cmdstr_supported([
	\	'keepjumps',
	\	])

" prev: 'noautocmd', 
let s:accepttag_switchtostartbuf_cmd_pref =
	\	ctrlp#utils#make_cmdstr_supported([
	\	'keepjumps',
	\	])

" s:tgcmd_searchexprdict_* functions {{{2

fu! s:tgcmd_searchexprdict_localinit()
	" prev: if get(s:, 'tgcmd_searchexprdict_initialised') | retu | en
	if exists('s:tgcmd_searchexprdict_stdexprs') | retu | en
	" prev: let s:tgcmd_searchexprdict_stdexprs = {
	" prev: 	\		'tgcmd_exprid_pref_common': '\V\C',
	" prev: 	\		'tgcmd_exprid_atom_linebeg': '\^',
	" prev: 	\		'tgcmd_exprid_atom_lineend': '\$',
	" prev: 	\		'tgcmd_exprid_atom_skipws_zeroormore_max': '\s\*',
	" prev: 	\		'tgcmd_cmdid_search_pref_common': '/',
	" prev: 	\	}
	let s:tgcmd_searchexprdict_stdexprs = {
		\		'tgcmd_exprid_pref_common': '\M\C',
		\		'tgcmd_exprid_atom_linebeg': '^',
		\		'tgcmd_exprid_atom_lineend': '$',
		\		'tgcmd_exprid_atom_skipws_zeroormore_max': '\s\*',
		\		'tgcmd_cmdid_search_pref_common': '/',
		\	}
	" prev: let s:tgcmd_searchexprdict_initialised = 1
endf

let s:tgcmd_searchexprdict_toplevelflatdict = 1

if get(s:, 'tgcmd_searchexprdict_toplevelflatdict')

fu! s:tgcmd_searchexprdict_getitem(exprdictkey, expr_dict) abort
	retu a:expr_dict[a:exprdictkey]
endf

el " s:tgcmd_searchexprdict_toplevelflatdict

" optional args:
"		* exprdict_dict_list | exprdict_dict:
"			either a single (exprdict_dict) or a list (exprdict_dict_list) of
"			dictionaries that have all been created with
"			ctrlp#tagutils#tgcmd_searchexprdict_createforpattern().
fu! s:tgcmd_searchexprdict_getitem(exprdictkey, ...) abort
	let expr_dicts_list =
		\	(a:0 ? ( ( type(a:1) == 4 ) ? [a:1] : a:1 ) : [])
		\	+ s:tgcmd_searchexprdict_stdexprs
	for expr_dict_now in expr_dicts_list
		if has_key(expr_dict_now, a:exprdictkey)
			retu expr_dict_now[a:exprdictkey]
		en
	endfo
	th printf(
		\	'%s could not find exprdictkey in any of the provided dictionaries. ' .
		\		'a:exprdictkey=%s; a:000=%s; expr_dicts_list=%s;',
		\	's:tgcmd_searchexprdict_getitem():',
		\	string(a:exprdictkey), string(a:000), string(expr_dicts_list))
endf

en " s:tgcmd_searchexprdict_toplevelflatdict

" Public functions {{{1

"- fu! s:tostring_or_na(v) ... endf

" returns a new dictionary with patterns based on a:pattern
fu! ctrlp#tagutils#tgcmd_searchexprdict_createforpattern(pattern)
	let log_pref = 'ctrlp#tagutils#tgcmd_searchexprdict_createforpattern():'

	cal s:tgcmd_searchexprdict_localinit()

	let pattern = a:pattern
	let [regex_matchstart, regex_matchend] = ['\zs', '\ze']
	" if none of the "forbidden" expressions show up in the source pattern
	" (if they do (just to be safe), we'll leave the pattern alone).
	if max(map(
		\	[regex_matchstart, regex_matchend],
		\	'stridx(pattern, v:val)')) < 0
		" insert regex_matchstart before the first non-whitespace atom/character.
		"- \	pattern, '\v^(%(\\[VMCc])*)(\s*)', '\1\2' . regex_matchstart, '')
		let pattern = substitute(
			\	pattern, '\v^(%(\\[VMCc])*)(\s*)', '\1\2\\zs', '')
	en

	cal ctrlp#ev_log_printf(
		\	'%s entered. ' .
		\		'a:pattern=%s; pattern=%s;',
		\	log_pref, string(a:pattern), string(pattern))

	if get(s:, 'tgcmd_searchexprdict_toplevelflatdict')
		let expr_dict = deepcopy(s:tgcmd_searchexprdict_stdexprs)
	el " s:tgcmd_searchexprdict_toplevelflatdict
		let expr_dict = {}
	en " s:tgcmd_searchexprdict_toplevelflatdict

	cal extend(
		\	expr_dict,
		\	map(
		\		{
		\			'tgcmd_exprid_tgstr_orig': 0,
		\			'tgcmd_exprid_tgstr_nows_all': ['\v^\s*(.{-})\s*$', '\1', ''],
		\			'tgcmd_exprid_tgstr_nows_lead': ['\v^\s*', '', ''],
		\			'tgcmd_exprid_tgstr_nows_trail': ['\v\s*$', '', ''],
		\		},
		\		'empty(v:val) ? pattern : ' .
		\			'call("substitute", [pattern] + v:val)'))

	retu expr_dict
endf

" * a:proc_list: list of lists. each element is a list with the following
"		format:
"		[ {exprdictkey_dst}, [ {exprdictkey_src_01}, ..., {exprdictkey_src_n} ] ]
"	This functiion will update a:expr_dict using definitions from a:proc_list in
"	the following manner:
"	For every given {exprdictkey_dst}, the concatenation of
"	s:tgcmd_searchexprdict_getitem(exprdictkey_src_i) is assigned to
"	a:expr_dict[{exprdictkey_dst}].
"
"	Example:
"		cal ctrlp#tagutils#tgcmd_searchexprdict_updatecombine(expr_dict, [
"			\ [ 'dstkey', [ 'src1', src2', src3' ] ],
"			\	])
"
"		will have the same effect as:
"		let expr_dict['dstkey'] =
"			\	s:tgcmd_searchexprdict_getitem('src1', expr_dict) .
"			\	s:tgcmd_searchexprdict_getitem('src2', expr_dict) .
"			\	s:tgcmd_searchexprdict_getitem('src3', expr_dict)
"
fu! ctrlp#tagutils#tgcmd_searchexprdict_updatecombine(expr_dict, proc_list)
	for [exprdictkey_dst, exprdictkeys_src_list] in a:proc_list
		unl! val
		let val = ''
		" MAYBE: IDEA: do this with:
		"		join(
		"			map(copy(exprdictkeys_src_now), 's:tgcmd_searchexprdict_getitem(v:val, a:expr_dict)'),
		"			'')
		"		instead.
		for exprdictkeys_src_now in exprdictkeys_src_list
			let val .=
				\	s:tgcmd_searchexprdict_getitem(exprdictkeys_src_now, a:expr_dict)
		endfo
		let a:expr_dict[exprdictkey_dst] = val
	endfo
	retu a:expr_dict
endf

" ref: fu! ctrlp#tagutils#tgcmd_searchexprdict_createforpattern(pattern)
fu! ctrlp#tagutils#tgcmd_searchexprdict_createstd(pattern)
	" ref: let s:tgcmd_searchexprdict_stdexprs = {
	" ref: fu! ctrlp#tagutils#tgcmd_searchexprdict_updatecombine(expr_dict, proc_list)
	if !exists('s:tgcmd_searchexprdict_proclist_std')
		let s:tgcmd_searchexprdict_proclist_std = [
			\		[ 'tgcmd_exprid_tgpattern_orig', [
			\				'tgcmd_exprid_pref_common',
			\				'tgcmd_exprid_atom_linebeg',
			\				'tgcmd_exprid_tgstr_orig',
			\				'tgcmd_exprid_atom_lineend',
			\			],
			\		],
			\		[ 'tgcmd_exprid_tgpattern_ignws_all', [
			\				'tgcmd_exprid_pref_common',
			\				'tgcmd_exprid_atom_linebeg',
			\				'tgcmd_exprid_atom_skipws_zeroormore_max',
			\				'tgcmd_exprid_tgstr_nows_all',
			\				'tgcmd_exprid_atom_skipws_zeroormore_max',
			\				'tgcmd_exprid_atom_lineend',
			\			],
			\		],
			\		[ 'tgcmd_exprid_tgpattern_ignws_lead', [
			\				'tgcmd_exprid_pref_common',
			\				'tgcmd_exprid_atom_linebeg',
			\				'tgcmd_exprid_atom_skipws_zeroormore_max',
			\				'tgcmd_exprid_tgstr_nows_lead',
			\				'tgcmd_exprid_atom_lineend',
			\			],
			\		],
			\		[ 'tgcmd_exprid_tgpattern_ignws_trail', [
			\				'tgcmd_exprid_pref_common',
			\				'tgcmd_exprid_atom_linebeg',
			\				'tgcmd_exprid_tgstr_nows_trail',
			\				'tgcmd_exprid_atom_skipws_zeroormore_max',
			\				'tgcmd_exprid_atom_lineend',
			\			],
			\		],
			\		[ 'tgcmd_exprid_tgpattern_substr_anyaround', [
			\				'tgcmd_exprid_pref_common',
			\				'tgcmd_exprid_tgstr_nows_all',
			\			],
			\		],
			\	]
	en
	let expr_dict = ctrlp#tagutils#tgcmd_searchexprdict_updatecombine(
		\	ctrlp#tagutils#tgcmd_searchexprdict_createforpattern(a:pattern),
		\	s:tgcmd_searchexprdict_proclist_std)
	retu expr_dict
endf

let s:gototag_data_validators = {
	\		'validatorexprid_nonempty': '!empty(v:val)',
	\	}

" TODO: move to a "local variables" section in this file.
" done: move definitions from ctrlp#tagutils#accept_tag() into here
"  done: add entry for the features/characteristics that are going to be used
"  from both ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict()
"  and ctrlp#tagutils#accept_tag().
let s:gototag_data_items_def_dict = {
	\		'set_cmd': {
	\				'arg_policy': 'req',
	\				'arg_allowed_types': [s:typeid_str],
	\				'arg_validator_expr':
	\					s:gototag_data_validators['validatorexprid_nonempty'],
	\				'sets_dataid': 'gtd_dataid_cmd',
	\			},
	\		'set_searchstring': {
	\				'arg_policy': 'req',
	\				'arg_allowed_types': [s:typeid_str],
	\				'arg_validator_expr':
	\					s:gototag_data_validators['validatorexprid_nonempty'],
	\				'sets_dataid': 'gtd_dataid_pattern',
	\			},
	\		'set_search_nearby_maxdistance': {
	\				'arg_policy': 'req',
	\				'arg_allowed_types': [s:typeid_num],
	\				'sets_dataid': 'gtd_dataid_nearbymaxdist',
	\			},
	\		'set_search_startpos': {
	\				'arg_policy': 'req',
	\				'arg_allowed_types': [s:typeid_num, s:typeid_list],
	\				'sets_dataid': 'gtd_dataid_searchstartpos',
	\				'arg_validator_expr':
	\					'(type(v:val) == s:typeid_list) ' .
	\						'? (index([3, 4], len(v:val)) >= 0) ' .
	\						': !0'
	\			},
	\		'findtag_tagcmd': {
	\				'item_type': 'itemtype_find_tag',
	\				'uses_dataids': ['gtd_dataid_cmd'],
	\			},
	\		'findtag_execmd': {
	\				'item_type': 'itemtype_find_tag',
	\				'uses_dataids': ['gtd_dataid_cmd'],
	\			},
	\		'findtag_searchnearby': {
	\				'arg_policy': 'opt',
	\				'arg_allowed_types': [s:typeid_str],
	\				'arg_validator_expr':
	\					s:gototag_data_validators['validatorexprid_nonempty'],
	\				'item_type': 'itemtype_find_tag',
	\				'uses_dataids': [
	\					'gtd_dataid_pattern',
	\					'gtd_dataid_searchstartpos', 'gtd_dataid_nearbymaxdist'],
	\			},
	\		'post_search_nearby': {
	\				'arg_policy': 'opt',
	\				'arg_allowed_types': [s:typeid_str],
	\				'arg_validator_expr':
	\					s:gototag_data_validators['validatorexprid_nonempty'],
	\				'item_type': 'itemtype_tagfound_post',
	\				'uses_dataids': ['gtd_dataid_pattern', 'gtd_dataid_nearbymaxdist'],
	\			},
	\		'post_execmd': {
	\				'item_type': 'itemtype_tagfound_post',
	\				'uses_dataids': ['gtd_dataid_cmd'],
	\			},
	\ }

" this function will return, depending on the verb:
"   * if the verb is an action with the ability to set the dataid it needs,
"			then we *could* return a single element list with the verb and the
"			optional parameter's value.
"				[	[ specified_verb, value_to_set ] ]
"		* if the verb needs a dataid that we don't know how to set, this throws.
"		* if the verb needs a dataid, then we find its setter and return a list
"			with (at least?) 2 elements:
"				[
"					[ verb_setter, value_to_set ],
"					[ specified_verb ],
"				]
"		* the value_to_set will depend on whether the dataid is a cmd or a
"			pattern.
"			NOTE: for now, we could make this decision with explicit code in this
"			function.
"			* if it's a pattern, then value_to_set will be exactly the value
"				retrieved from
"				s:tgcmd_searchexprdict_getitem(a:exprdictkey, a:expr_dict)
"			* if it's a cmd, then we prepend
"				s:tgcmd_searchexprdict_getitem('tgcmd_cmdid_search_pref_common', a:expr_dict)
"				to the pattern value (which would have been retrieved using the
"				expression above).
fu! ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\	expr_dict, gototag_item_verb, exprdictkey)
	let log_pref = 'ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict():'
	let except_pref = log_pref

	" done: store this dict in a 's:' variable to avoid recalculating this
	" every time.
	" prev: let dataid_setter_verbs_dict = {}
	" prev: for gtd_verb_now in filter(
	" prev: 		\	keys(s:gototag_data_items_def_dict),
	" prev: 		\	'(!has_key(s:gototag_data_items_def_dict[v:val], ''item_type'')) ' .
	" prev: 		\		'&& (!empty(' .
	" prev: 		\				'get(s:gototag_data_items_def_dict[v:val], ''sets_dataid'')))')
	" prev: 	let dataid_setter_verbs_dict[
	" prev: 		\	s:gototag_data_items_def_dict[gtd_verb_now]['sets_dataid']] =
	" prev: 		\		gtd_verb_now
	" prev: endfo
	if !exists('s:gototag_data_dataid_setters_dict')
		let s:gototag_data_dataid_setters_dict = {}
		for gtd_verb_now in filter(
				\	keys(s:gototag_data_items_def_dict),
				\	'(!has_key(s:gototag_data_items_def_dict[v:val], ''item_type'')) ' .
				\		'&& (!empty(' .
				\				'get(s:gototag_data_items_def_dict[v:val], ''sets_dataid'')))')
			let s:gototag_data_dataid_setters_dict[
				\	s:gototag_data_items_def_dict[gtd_verb_now]['sets_dataid']] =
				\		gtd_verb_now
		endfo
	en

	let gototag_item_def =
		\	get(s:gototag_data_items_def_dict, a:gototag_item_verb)
	if empty(gototag_item_def)
		th printf(
			\	'%s a:gototag_item_verb unknown/unsupported. ' .
			\		'a:gototag_item_verb=%s;',
			\	except_pref, string(a:gototag_item_verb))
	en

	let gtd_dataids_list = get(gototag_item_def, 'uses_dataids')
	if empty(gtd_dataids_list)
		th printf(
			\	'%s a:gototag_item_verb does not use any dataids. ' .
			\		'a:gototag_item_verb=%s; gototag_item_def=%s;',
			\	except_pref,
			\	string(a:gototag_item_verb), string(gototag_item_def))
	en

	let valtoset_base = s:tgcmd_searchexprdict_getitem(a:exprdictkey, a:expr_dict)

	let gototag_data_list = []
	" NOTE: for now, we only set the first dataid from the value generated from
	" a:exprdictkey.
	for dataid_to_set in gtd_dataids_list[:0]
		unl! valtoset_now
		let valtoset_now = valtoset_base

		" for commands, we turn the pattern into a command that uses it.
		if dataid_to_set ==# 'gtd_dataid_cmd'
			let valtoset_now = 
				\	s:tgcmd_searchexprdict_getitem(
				\		'tgcmd_cmdid_search_pref_common', a:expr_dict) .
				\	valtoset_now
		" elsei dataid_to_set ==# 'gtd_dataid_pattern'
		en

		cal add(
			\	gototag_data_list,
			\	[ s:gototag_data_dataid_setters_dict[dataid_to_set],
			\		valtoset_now ])
	endfo
	" for now, we will only support one "setter" element only, just to make sure
	" that we won't be setting the same thing twice (one as a command, one as a
	" search pattern, for example), which we yet don't have a case for.
	let gototag_data_list_len = len(gototag_data_list)
	if gototag_data_list_len != 1
		th printf(
			\	'%s generated gototag_data_list has the wrong number ' .
			\		'of elements. ' .
			\		'gtd_dataids_list=%s; ' .
			\		'len(gototag_data_list)=%d; gototag_data_list=%s;',
			\	except_pref, string(gtd_dataids_list),
			\	gototag_data_list_len, string(gototag_data_list))
	en
	cal add(gototag_data_list, [ a:gototag_item_verb ])

	cal ctrlp#ev_log_printf(
		\	'%s generated gototag_data_list. ' .
		\		'gototag_data_list=%s; ' .
		\		'a:gototag_item_verb=%s; a:exprdictkey=%s;',
		\	log_pref, string(gototag_data_list),
		\	string(a:gototag_item_verb), string(a:exprdictkey))
	retu gototag_data_list
endf

fu! ctrlp#tagutils#accept_tag_gototagdata_verbusesdataid(
		\	gototag_item_verb, gototag_data_dataid)
	let log_pref = 'ctrlp#tagutils#accept_tag_gototagdata_verbusesdataid():'
	let except_pref = log_pref

	let gototag_item_def =
		\	get(s:gototag_data_items_def_dict, a:gototag_item_verb)
	if empty(gototag_item_def)
		th printf(
			\	'%s a:gototag_item_verb unknown/unsupported. ' .
			\		'a:gototag_item_verb=%s;',
			\	except_pref, string(a:gototag_item_verb))
	en

	let gtd_dataids_list = get(gototag_item_def, 'uses_dataids', [])
	" prev: if empty(gtd_dataids_list)
	" prev: 	retu 0
	" prev: en
	retu index(gtd_dataids_list, a:gototag_data_dataid) >= 0
endf

" required args:
"		* start_curpos: if empty (usually, zero), then get it from the current
"			cursor position (ctrlp#utils#getcurpos()).
" optional args:
"		* start_bufnr: if unspecified, it gets it from a:start_curpos[0].
"			if zero (or if unspecified and a:start_curpos[0] is zero), uses the
"			current buffer (bufnr('%')).
"		* flags (latter options override previous ones):
"			'j'/'J': use (/don't use) jumplist to search backwards;
"			'a'/'A': add (/don't) an entry to the jumplist (if one wasn't found);
" prev: fu! s:accepttag_goto_startpos(start_curpos, ...)
fu! ctrlp#tagutils#gobacktostartpos(start_curpos, ...)
	let log_pref = 'ctrlp#tagutils#gobacktostartpos():'
	let except_pref = log_pref
	" prev: let start_curpos = a:start_curpos
	let start_curpos = empty(a:start_curpos)
		\	? ctrlp#utils#getcurpos() : a:start_curpos
	let start_bufnr = a:0 ? a:1 : start_curpos[0]
	if start_bufnr == 0
		let start_bufnr = bufnr('%')
	en
	"? let proc_flags = 'JA' . (a:0 > 1 : a:2 : '')
	"? let proc_flags = '' . (a:0 > 1 : a:2 : '')
	let proc_flags = a:0 > 1 ? a:2 : ''
	let printf_fmt_regex_procflagonlythis =
		\	'\M%s\[^%s]\*$'
	for [procflagget_var, procflagget_flagval_ena, procflagget_flagval_dis] in
			\	[
			\		[ 'proc_flag_search_backwards_jumplist', 'j', 'J' ],
			\		[ 'proc_flag_add_jumplist_entry', 'a', 'A' ],
			\	]
		let {procflagget_var} =
			\	(proc_flags =~#
			\		printf(
			\			printf_fmt_regex_procflagonlythis,
			\			procflagget_flagval_ena, procflagget_flagval_dis))
	endfo

	" prev: let use_jumplist = has('jumplist')
	let use_jumplist = has('jumplist')
	let proc_flag_search_backwards_jumplist =
		\	proc_flag_search_backwards_jumplist && use_jumplist
	let proc_flag_add_jumplist_entry =
		\ proc_flag_add_jumplist_entry && use_jumplist
	cal ctrlp#ev_log_printf(
		\	'%s entered. a:start_curpos=%s; a:000=%s; ' .
		\		'start_bufnr=%d; start_curpos=%s; proc_flags=%s; ' .
		\		'proc_flag_search_backwards_jumplist=%d; ' .
		\		'proc_flag_add_jumplist_entry=%d;',
		\	log_pref, string(a:start_curpos), string(a:000),
		\	start_bufnr, string(start_curpos), string(proc_flags),
		\	proc_flag_search_backwards_jumplist,
		\	proc_flag_add_jumplist_entry)

	try
		" prev: let t_shortmess_rv = ctrlp#utils#set_opt_shortmess_nomessages()
		" prev: if t_shortmess_rv[0] | let sav_shortmess = t_shortmess_rv[1] | en
		" prev: unl t_shortmess_rv
		let sav_shortmess = ctrlp#utils#set_opt_shortmess_nomessages()[1]
		if !&hidden
			let sav_hidden = &hidden
			set hidden
		en

		" go to our "starting" position
		" prev: " prev: if use_jumplist
		" prev: if proc_flag_search_backwards_jumplist
		if use_jumplist
			" prev: let cmd_jumplist_jmp_common_pref = 'normal! '
			"-? let cmd_jumplist_jmp_common_pref = 'keepjumps normal! '
			" prev: let cmd_jumplist_jmp_common_pref = 'normal! '
			let cmd_jumplist_jmp_common_pref = 'normal! '
			let cmd_jumplist_jmpnotrace_pref =
				\	'keepjumps ' . cmd_jumplist_jmp_common_pref
			let cmd_jumplist_jmp_back_suff = "\<c-o>"
			let cmd_jumplist_jmp_fwd_suff = "\<c-i>"
		en
		if proc_flag_add_jumplist_entry
			let proc_addjumplistentry_flag = !0
		en

		"? cal ctrlp#ev_log_printf(
		"? 	\	'%s about to try to find the starting position. ' .
		"? 	\		'start_bufnr=%d; start_curpos=%s;',
		"? 	\	log_pref, start_bufnr, string(start_curpos))
		let [at_startpos, njumps_done] = [0, 0]
		try
			" prev: for njumps_done in range(0, 2)
			wh 1
				let [cur_bufnr, cur_curpos] = [bufnr('%'), ctrlp#utils#getcurpos()]
				let at_startpos = (
					\	(cur_bufnr == start_bufnr)
					\	&& (cur_curpos[1:3] == start_curpos[1:3]))
				cal ctrlp#ev_log_printf(
					\	'%s iteration: calculated at_startpos. ' .
					\		'at_startpos=%d; cur_bufnr=%d; cur_curpos=%s; ' .
					\		'proc_flag_search_backwards_jumplist=%d; njumps_done=%d; ' .
					\		'&l:buflisted=%d;',
					\	log_pref, at_startpos, cur_bufnr, string(cur_curpos),
					\	proc_flag_search_backwards_jumplist, njumps_done,
					\	&l:buflisted)
				if !proc_flag_search_backwards_jumplist | brea | en
				" prev: if at_startpos | brea | en
				" prev: if njumps_done == 2 | brea | en
				if at_startpos || (njumps_done == 2) | brea | en
				" NOTE: the cursor could be at a position that isn't in the
				" jumplist, so in order to check both the current buffer+cursor
				" position and the "current" jumplist entry, we need to force moving
				" to the last entry, which could still match the "current" jumplist
				" entry.  We've already determined that !at_startpos holds, so now
				" we force moving to the "current" jumplist entry and loop again
				" without updating 'njumps_done', as going back to the "current"
				" position would not cause a jumplist entry to be added (because of
				" the 'keepjumps' prefix above).
				"  NOTE: restoring the sav_bufnr_loc+sav_curpos_loc is optional, as
				"  we would like to move to the requested position (potentially)
				"  disregarding the current position.
				if (njumps_done == 0) && (!exists('sav_bufnr_loc'))
					let [sav_bufnr_loc, sav_curpos_loc] =
						\	[bufnr('%'), ctrlp#utils#getcurpos()]
					cal ctrlp#ev_log_printf(
						\	'%s first iteration: jump to current jumplist entry and save ' .
						\		'current cursor position. sav_bufnr_loc=%d; sav_curpos_loc=%s;',
						\	log_pref, sav_bufnr_loc, string(sav_curpos_loc))
					" now jump to the "current" jumplist entry
					"+? try
						exe cmd_jumplist_jmpnotrace_pref .
							\	'1' . cmd_jumplist_jmp_back_suff
						exe cmd_jumplist_jmpnotrace_pref .
							\	'1' . cmd_jumplist_jmp_fwd_suff
					"+? cat
						" MAYBE: could this happen with an empty jumplist?
					"+? endt
					" loop again, which should not enter this 'if' and should start
					" going back the jumplist.
					con
				en
				" raising an exception would also keep njumps_done unchanged.
				exe cmd_jumplist_jmpnotrace_pref .
					\	'1' . cmd_jumplist_jmp_back_suff
				" Detect if this "go to previous entry in the jumplist" has done
				" something.  If it hasn't, then we can't rely on a future
				" njumps_done value being an accurate representation of the
				" number of jumps having been made.
				if cur_curpos == ctrlp#utils#getcurpos() | brea | en
				let njumps_done += 1
			" prev: endfo
			endw
			" prev: let proc_addjumplistentry_flag = !at_startpos
			if proc_flag_add_jumplist_entry
				let proc_addjumplistentry_flag = (!at_startpos) || (njumps_done == 0)
			en

		fina
			if (!at_startpos) && (njumps_done > 0)
				cal ctrlp#ev_log_printf(
					\	'%s start_curpos not found in the jumplist. ' .
					\		'going back to the starting position in the jumplist. ' .
					\		'at_startpos=%d; njumps_done=%d;',
					\	log_pref, at_startpos, njumps_done)
				exe cmd_jumplist_jmpnotrace_pref .
					\	njumps_done . cmd_jumplist_jmp_fwd_suff
			en
		endt
		" prev: " prev: if bufnr('%') != start_bufnr
		" prev: " prev: 	exe 'silent!' s:accepttag_switchtostartbuf_cmd_pref 'b' start_bufnr
		" prev: " prev: en
		" prev: " prev: if bufnr('%') != start_bufnr
		" prev: " prev: 	" MAYBE: throw an exception instead?
		" prev: " prev: 	retu 0
		" prev: " prev: en
		" prev: " prev: if cur_curpos[1:3] != start_curpos[1:3]
		" prev: " prev: 	" NOTE: from vim-7.0 documentation:
		" prev: " prev: 	" setpos(): "does not change the jumplist"
		" prev: " prev: 	cal setpos('.', start_curpos)
		" prev: " prev: en

		" NOTE: as we're going "back" to the "start" position, saving the current
		" position is not really necessary or even (arguably) desirable: wherever
		" we are at the moment, it's not where we'd like to start from, and it
		" should be considered a position past the "starting" point, therefore
		" we're conceptually "undoing" whichever movements (/buffer switching)
		" that might have been been done up to this point.
		" NOTE: also, the caller can always execute this 'normal! m'' command if
		" it wants to save the current position (at which point, it might not
		" still know whether the "go back" would use the jumplist entries leading
		" to the current position or not), on the assumption that by doing that,
		" only the following entries in the jumplist would be lost, but those
		" can be assumed (in the context of this function) to be of no interest to
		" us, as we're going back to the "start" position, presumably to try to
		" move to another, potentially "better" target buffer/position.
		" add an entry at the current position for the jumplist
		" prev: " NOTE: see also comments inside the following 'for' loop.
		" prev: if use_jumplist && proc_addjumplistentry_flag
		" prev: 	normal! m'
		" prev: en

		" prev: for stage_key in ['stageid_buf', 'stageid_pos']
		" prev: 	if stage_key ==# 'stageid_buf'
		" prev: 		let post_cond_expr = 'bufnr(''%'') == start_bufnr'
		" prev: 		let action_cmd = s:accepttag_switchtostartbuf_cmd_pref 'b' start_bufnr
		" prev: 	elsei stage_key ==# 'stageid_buf'
		" prev: 		let post_cond_expr = 'cur_curpos[1:3] == start_curpos[1:3]'
		" prev: 		let action_cmd = 'cal setpos(''.'', start_curpos)'
		" prev: 	el
		" prev: 		throw printf(
		" prev: 			\	'%s internal error: invalid stage_key: %s',
		" prev: 			\	except_pref, string(stage_key))
		" prev: 	en
		" prev: endfo
		" NOTE: switching buffers would normally add an entry to the jumplist right where
		" the focus was when this function was entered, so we refrain from doing
		" that at that point, and use the manually saved position, which was done
		" above.
		"?  \			(s:accepttag_switchtostartbuf_cmd_pref . ' b ' . start_bufnr),
		cal ctrlp#ev_log_printf(
			\	'%s about to move to the starting position. ' .
			\		'start_bufnr=%d; start_curpos=%s;',
			\	log_pref,
			\	start_bufnr, string(start_curpos))
		for [stage_key, post_cond_expr, action_cmd] in [
				\		[
				\			'stageid_buf',
				\			'bufnr(''%'') == start_bufnr',
				\			printf(
				\				'%s %db', s:accepttag_switchtostartbuf_cmd_pref, start_bufnr),
				\		],
				\		[
				\			'stageid_pos',
				\			'ctrlp#utils#getcurpos()[1:3] == start_curpos[1:3]',
				\			'cal setpos(''.'', start_curpos)',
				\		],
				\	]
			cal ctrlp#ev_log_printf(
				\	'%s about to check whether the stage post-condition ' .
				\		'is met already. ' .
				\		'bufnr()=%d; curpos=%s; &l:buflisted=%d; ' .
				\		'stage_key=%s; post_cond_expr=%s;',
				\	log_pref,
				\	bufnr('%'), string(ctrlp#utils#getcurpos()), &l:buflisted,
				\	string(stage_key), string(post_cond_expr))
			silent! if !empty(post_cond_expr) && eval(post_cond_expr) | con | en
			cal ctrlp#ev_log_printf(
				\	'%s about to execute positioning command. ' .
				\		'bufnr()=%d; curpos=%s; &l:buflisted=%d; ' .
				\		'stage_key=%s; post_cond_expr=%s; action_cmd=%s;',
				\	log_pref,
				\	bufnr('%'), string(ctrlp#utils#getcurpos()), &l:buflisted,
				\	string(stage_key), string(post_cond_expr), string(action_cmd))
			silent! exe action_cmd
			"? exe 'silent!' action_cmd
			silent! if !empty(post_cond_expr) && eval(post_cond_expr) | con | en
			" MAYBE: throw an exception instead? (configurable?)
			cal ctrlp#ev_log_printf(
				\	'%s last cursor movement command does not seem to have worked. ' .
				\		'returning 0. ' .
				\		'bufnr()=%d; curpos=%s; &l:buflisted=%d;',
				\	log_pref,
				\	bufnr('%'), string(ctrlp#utils#getcurpos()), &l:buflisted)
			retu 0
		endfo

		" add an entry at the current position for the jumplist
		" prev: if use_jumplist && proc_addjumplistentry_flag
		if proc_flag_add_jumplist_entry && proc_addjumplistentry_flag
			cal ctrlp#ev_log_printf(
				\	'%s about to add a jumplist entry at the current cursor position. ' .
				\		'bufnr=%d; bufname=%s; curpos=%s; &l:buflisted=%d;',
				\	log_pref, bufnr('%'), string(bufname('%')),
				\	string(ctrlp#utils#getcurpos()), &l:buflisted)
			" add an entry at the current cursor position, then jump to the jumplist
			" entry, so the current position matches the last entry in the jumplist
			" -- this will allow the next movement to:
			" * if it's a 'keepjumps' one, then this entry will remain in the
			"		jumplist;
			"	* if the command/code adds an entry to the jumplist, then vim should
			"		(might) discard the duplicate;
			normal! m'
			exe cmd_jumplist_jmp_common_pref .
				\	'1' . cmd_jumplist_jmp_back_suff
		en

		cal ctrlp#ev_log_printf('%s returning success (!0)', log_pref)
		retu !0

	fina
		if exists('sav_shortmess') && (&shortmess != sav_shortmess)
			let &shortmess = sav_shortmess
		en
		if exists('sav_hidden') && (&hidden != sav_hidden)
			let &hidden = sav_hidden
		en
	endt
endf

" done: create a s:search_nearby_move(pattern) -> bool
"  done: do not change cursor position, unless the search has
"  been succcessful.
"  done: do not assume anything about the search string, 'magic'
"  settings, etc.
"  done: see comments about using ranges to minimise the amount
"  of lines access/CPU, whilst minimising the number of
"  searches, too.
fu! s:search_nearby_move(pattern, maxdist) abort
	let log_pref = 's:search_nearby_move():'
	let [line_min, line_start, line_max] = [1, line('.'), line('$')]
	let search_opt_pref = 'Wn'
	cal ctrlp#ev_log_printf(
		\	'%s entered. ' .
		\		'a:pattern=%s; a:maxdist=%d; ' .
		\		'line_start=%d; line_max=%d; ',
		\	log_pref, string(a:pattern), a:maxdist, line_start, line_max)
	" map negative values to mean "as far (much) as possible".
	let dist_max_max = (a:maxdist < 0) ? line_max : a:maxdist
	" adjust the distance to be the maximum available distance between
	" line_start and the new search (line) boundaries.
	let line_min = max([line_min, line_start - dist_max_max])
	let line_max = min([line_max, line_start + dist_max_max])
	" prev: let dist_max_max = max([line_start - line_min, line_max - line_start])
	let dist_max_fwd = line_max - line_start
	let dist_max_bwd = line_start - line_min
	let dist_max_max = max([dist_max_fwd, dist_max_bwd])
	let dist_max_min = min([dist_max_fwd, dist_max_bwd])
	cal ctrlp#ev_log_printf(
		\	'%s adjusted search parameters. ' .
		\		'line_start=%d; ' .
		\		'dist_max_bwd=%d; dist_max_fwd=%d; ' .
		\		'line_min=%d; line_max=%d; ' .
		\		'dist_max_min=%d; dist_max_max=%d;',
		\	log_pref,
		\	line_start,
		\	dist_max_bwd, dist_max_fwd,
		\	line_min, line_max,
		\	dist_max_min, dist_max_max)

	" prev: let line_searchres = search(a:pattern, search_opt_pref . 'c', line_start)
	" NOTE: allow moving the cursor within the line to the "match start"
	" position/atom.
	let line_searchres = search(
		\	a:pattern,
		\	substitute(search_opt_pref, 'n', '', 'g') . 'c',
		\	line_start)
	if line_searchres > 0
		cal ctrlp#ev_log_printf(
			\	'%s found pattern at cursor line/cursor position.',
			\	log_pref)
		retu !0
	en

	if !exists('s:search_nearby_distances_fixed')
		let s:search_nearby_distances_fixed = []
		let line_val_now = 32
		"? wh !0
		"? 	cal add(s:search_nearby_distances_fixed, line_val_now)
		"? 	if line_val_now > 1024 | brea | en
		"? 	let line_val_now *= 4
		"? endw
		wh line_val_now <= 1024
			cal add(s:search_nearby_distances_fixed, line_val_now)
			let line_val_now = line_val_now * 4
		endw
	en

	let impl_use_dyndistcalc_flag = !0
	let impl_use_searchparams_list_flag = !impl_use_dyndistcalc_flag

	if impl_use_dyndistcalc_flag

	" done: implement.
	"  IDEA: store/calculate potential distances, and adjust based on line_min,
	"  line_max and line_start.  Once we reach an edge (whichever), we search up
	"  to the line number of the other edge.
	"  If we find a match, the distance from line_start up to the matching line
	"  becomes the new (and final) distance to search in the other direction, as
	"  there is no point in finding a match whose distance will be then
	"  discarded as a "worse best match".
	"  We can order the search pair like this:
	"   for searchkey in ['fwd', 'bwd'] ...
	"  We can have results (which is updated as the searches progress) based on
	"  those keys, we can have the search options (which is read-only inside the
	"  loop) based on those keys.
	" prev: let searchinfo_dict = {
	" prev: 	\	'fwd': {
	" prev: 	\			'search_flags': search_opt_pref . '',
	" prev: 	\			'line_farthest_MAYBENOT': line_max,
	" prev: 	\			'dist_max_unbounded': dist_max_fwd,
	" prev: 	\		},
	" prev: 	\	'bwd': {
	" prev: 	\			'search_flags': search_opt_pref . 'b',
	" prev: 	\			'line_farthest_MAYBENOT': line_min,
	" prev: 	\			'dist_max_unbounded': dist_max_bwd,
	" prev: 	\		},
	" prev: 	\	}
	" NOTE: searching forwards should include the cursor position ('c'), as:
	"		* on the first iteation, the searches are going to be started from
	"		  'line_start', but only one of them (in this case, the 'fwd' search)
	"		  will consider the cursor position;
	"
	"		* on other iterations, the cursor would have been moved to a suitable
	"			'line_start_now', and to the first character, and thus:
	"
	"			* 'fwd': we'd like to consider that first position as a suitable match
	"				position when searching forwards, as we'll be moving to the actual
	"				first matching position then;
	"
	"			*	'bwd':
	"
	"				* if 'c' is in 'search_flags': then we can move the cursor to the
	"					last position in the calculated value for 'line_start_now', and
	"					this would behave in the same manner as the 'fwd' case does (as it
	"					also has a 'c' in 'search_flags', and moves to the first character
	"					in the calculated 'line_start_now').
	"
	"				* if 'c' is not in 'search_flags': then we start the search in the
	"					first character of the following line.
	"					NOTE: that the 'line_start_now' can always safely be added to when
	"					searching backwards, as:
	"
	"					* when 'line_start_now == line_start', the first character
	"						position in that line is also covered by the 'fwd' case;
	"
	"					* for following searches (for 'bwd'),
	"						'line_start_now < line_start', so in particular:
	"						line_start_now + 1 <= line_start <= line_max
	"
	" there will not be an overlapping point between searching backwards and
	" forwards other than the starting position.
	let searchinfo_dict = {
		\	'fwd': {
		\			'search_flags': search_opt_pref . 'c',
		\			'dist_max_unbounded': dist_max_fwd,
		\			'search_pre_cmd': 'normal! 0',
		\		},
		\	'bwd': {
		\			'search_flags': search_opt_pref . 'c' . 'b',
		\			'dist_max_unbounded': dist_max_bwd,
		\		},
		\	}
	let searchinfo_dict_entry = searchinfo_dict['bwd']
	if searchinfo_dict_entry['search_flags'] =~# 'c'
		let searchinfo_dict_entry['search_pre_cmd'] = 'normal! $'
	el
		" NOTE: empty commands should be ignored, so it's safe to store that if we
		" don't have a command in the 'fwd' entry.
		let searchinfo_dict_entry['search_pre_cmd'] =
			\	get(searchinfo_dict['fwd'], 'search_pre_cmd', '')
		let searchinfo_dict_entry['offset_linestart'] = 1
	en
	" initialise the "state" dictionary entries (which are dictionaries
	" themselves) for each key present in 'searchinfo_dict'.
	let searchstate_dict = map(
		\	copy(searchinfo_dict),
		\	'{}')

	" done: add condition to detect that we've finished searching
	"  (or code inside the 'while' to 'break' from it when that happens).
	"  done: have an element in
	"   searchstate_dict[searchkey]: 'search_done': boolean
	"? wh empty(filter(
	"? 		\	values(searchstate_dict),
	"? 		\	'get(v:val, ''line_matched'', 0) > 0'))
	let dist_ideal = 0
	wh (!empty(filter(
			\	values(searchstate_dict),
			\	'get(v:val, ''search_done'', 0) == 0')))
			\ &&
			\	empty(filter(
			\		values(searchstate_dict),
			\		'get(v:val, ''line_matched'', 0) > 0'))
		" prev: let dist_ideal = exists('dist_ideal')
		" prev: 	\	?	dist_ideal * 4
		" prev: 	\	:	32
		let dist_ideal = (dist_ideal > 0)
			\	?	dist_ideal * 4
			\	:	32
		for searchkey in ['fwd', 'bwd']
			let [searchinfo_dict_entry, searchstate_dict_entry] =
				\	[searchinfo_dict[searchkey], searchstate_dict[searchkey]]
			cal ctrlp#ev_log_printf(
				\	'%s starting search loop iteration. ' .
				\		'searchkey=%s; ' .
				\		'searchinfo_dict_entry=%s; searchstate_dict_entry=%s; ' .
				\		'dist_ideal=%d;',
				\	log_pref,
				\	string(searchkey),
				\	string(searchinfo_dict_entry), string(searchstate_dict_entry),
				\	dist_ideal)
			if get(searchstate_dict_entry, 'search_done') | con | en

			let searchnow_isfwd = (searchkey ==# 'fwd')
			let dist_max_now = exists('dist_max_found')
				\	? dist_max_found : searchinfo_dict_entry['dist_max_unbounded']
			" if we determine there won't be anything to be done after this
			" iteration,
			"? let dist_now = min([dist_ideal, dist_max_now])
			if dist_ideal >= dist_max_now
				" mark this branch as done
				let searchstate_dict_entry['search_done'] = 1
				" set variable(s) so that the next search loop iteration will use as
				" big a value as possible for 'dist_max_now'.
				" NOTE: even if that value is then increased, the same bounds checking
				" logic will still cause the same "search as far as possible for this
				" branch" behaviour.
				let dist_ideal = dist_max_max
				" and adjust the distance to search in
				let dist_now = dist_max_now
			el
				let dist_now = dist_ideal
			en
			let line_stop_now = searchnow_isfwd
				\	?	line_start + dist_now
				\	:	line_start - dist_now
			let line_stop_prev = get(searchstate_dict_entry, 'line_stop_last', -1)
			" prev: if line_stop_prev >= 0
			" prev: 	if searchnow_isfwd
			" prev: 		let line_start_now = line_stop_prev + 1
			" prev: 	el
			" prev: 		let line_start_now = line_stop_prev - 1
			" prev: 	en
			" prev: el
			" prev: 	let line_start_now = line_start
			" prev: en
			let line_start_now =
				\	(line_stop_prev >= 0)
				\	?	(	(	searchnow_isfwd
				\				?	line_stop_prev + 1
				\				:	line_stop_prev - 1
				\			) +
				\			get(searchinfo_dict_entry, 'offset_linestart', 0)
				\		)
				\	:	line_start

			let search_flags_now = searchinfo_dict_entry['search_flags']
			cal ctrlp#ev_log_printf(
				\	'%s about to perform search. ' .
				\		'line_start_now=%d; ' .
				\		'line_stop_now=%d; ' .
				\		'dist_ideal=%d; dist_max_now=%d; dist_now=%d; ' .
				\		'search_flags_now=%s;',
				\	log_pref,
				\	line_start_now,
				\	line_stop_now,
				\	dist_ideal, dist_max_now, dist_now,
				\	string(search_flags_now))

			let search_pre_cmd_list = []

			" NOTE: our caller(s) are (should be) responsible for restoring the
			" window + buffer + cursor state if this function returns zero, so we
			" will happily move the cursor within this function, as needed, and rely
			" on that behaviour.
			" if we are moving from our original position,
			"-? if line('.') != line_start
			if line_start_now != line_start
				"? cal add(
				"? 	\	search_pre_cmd_list,
				"? 	\	(s:accepttag_movetobufcur_nojumps_cmd_pref line_start_now))
				"? let search_pre_cmd_post =
				"? 	\	get(searchinfo_dict_entry, 'search_pre_cmd', '')
				"? if !empty(search_pre_cmd_post)
				"? 	cal add(
				"? 		\	search_pre_cmd_list,
				"? 		\	(s:accepttag_movetobufcur_nojumps_cmd_pref search_pre_cmd))
				"? en
				cal extend(
					\	search_pre_cmd_list,
					\	[
					\		line_start_now . '',
					\		get(searchinfo_dict_entry, 'search_pre_cmd', ''),
					\	])
			en
			if !empty(filter(search_pre_cmd_list, '!empty(v:val)'))
				cal map(
					\	search_pre_cmd_list,
					\	's:accepttag_movetobufcur_nojumps_cmd_pref . '' silent '' . v:val')
				" MAYBE: execute elements separately, to avoid a line starting with
				" 'normal! ...' to alter the way in which the separator would be
				" interpreted (as part of that 'normal! ...' keystroke sequence).
				let search_pre_cmd = join(search_pre_cmd_list, ' | ')
				cal ctrlp#ev_log_printf(
					\	'%s about to execute pre-search command just before the search. ' .
					\		'search_pre_cmd=%s;',
					\	log_pref, string(search_pre_cmd))
				exe search_pre_cmd
			en
			let line_searchres = search(
				\	a:pattern, search_flags_now, line_stop_now)
			if line_searchres > 0
				" prev: let dist_max_found = ctrlp#utils#abs(line_searchres - line_start)
				let dist_matched_now = ctrlp#utils#abs(line_searchres - line_start)
				let searchstate_dict_entry['search_done'] = 1
				let searchstate_dict_entry['line_matched'] = line_searchres
				" prev: let searchstate_dict_entry['dist_matched'] = dist_max_found
				let searchstate_dict_entry['dist_matched'] = dist_matched_now
				"+? " MAYBE: just store the dist_matched_now, regardless of whether it is
				"+? " the minimum of all the dist_matched_now values (across iterations),
				"+? " as we know we have only two iterations, and if there is a second
				"+? " value that might overwrite the first (and that value being greater
				"+? " than the first), no other iteration is going to use it.
				"+? if exists('dist_max_found')
				"+? 	let dist_max_found = min([dist_max_found, dist_matched_now])
				"+? el
				"+? 	let dist_max_found = dist_matched_now
				"+? en
				let dist_max_found = dist_matched_now
			en

			let searchstate_dict_entry['line_stop_last'] = line_stop_now
		endfo
	endw
	cal ctrlp#ev_log_printf(
		\	'%s exited search loop. ' .
		\		'searchstate_dict=%s;',
		\	log_pref, string(searchstate_dict))

	" prev: " this is cheaper than going through searchstate_dict -- this will do for
	" prev: " now.
	" prev: if !exists('dist_max_found')
	" prev: 	cal ctrlp#ev_log_printf('%s pattern not found. returning 0.', log_pref)
	" prev: 	retu 0
	" prev: en

	" find the match closest to line_start.
	let [match_distance_min, match_line] = [dist_max_max + 1, line_min - 1]
	for searchstate_dict_entry in values(searchstate_dict)
		let dist_matched_now = get(searchstate_dict_entry, 'dist_matched', -1)
		if dist_matched_now < 0 | con | en
		let line_matched_now = searchstate_dict_entry['line_matched']

		" if this is a "better" (or equally as good) match as the best we had up
		" until now...
		if (dist_matched_now < match_distance_min)
				\	|| ((dist_matched_now == match_distance_min)
				\			&& (line_matched_now >= match_line))
			let [match_distance_min, match_line] =
				\	[dist_matched_now, line_matched_now]
		en
	endfo

	if match_line < line_min
		cal ctrlp#ev_log_printf('%s pattern not found. returning 0.', log_pref)
		retu 0
	en

	elsei impl_use_searchparams_list_flag

	" TODO: cache a calculated list for a key based on line_max and line_start
	"  (something like: 'nlines={line_max}:start={line_start}'), so we can avoid
	"  re-calculating when our caller has repeated calls to this function.
	"  TODO: then, in our callers, call a tagutils function (to be created) to
	"  get rid of that cache
	"   TODO: call that from ctrlp#tagutils#accept_tag(), for example.
	let searchparams_list = []
	let line_distance_prev = 0
	" NOTE: these values are set up to hold on the first check against them.
	" prev: let [lineproc_min, lineproc_max] = [line_max, line_min]
	let [lineproc_min, lineproc_max] = [line_max + 1, line_min - 1]
	" prev: \	map(range(25, 100, 25), 'line_max * v:val / 100')
	" prev: \	map(range(25, 99, 25), 'line_max * v:val / 100')
	" done: for small files, these "percentages" calculations seem unnecessary
	" or too "fine-grained".
	"  IDEA: #1: only process entries that are greater than the max for
	"  s:search_nearby_distances_fixed
	"  done: #2: almost the same as IDEA #1: but instead of starting with the
	"  'sort()' for the combined list, start with both lists as they are, as
	"  they're both sorted anyway, and we can position the "fixed" one first
	"  anyway:
	"   for ... in s:search_nearby_distances_fixed + map(range(...), ...)
	" NOTE: the 'for' expression below worked, but generated too many iterations
	" for small files.
	" prev: for line_distance_now in sort(
	" prev: 	\	map(range(25, 100, 25), 'line_max * v:val / 100')
	" prev: 	\	+ s:search_nearby_distances_fixed)
	"
	" prev: \	map(range(25, 100, 25), 'line_max * v:val / 100')
	for line_distance_now in 
		\	s:search_nearby_distances_fixed
		\	+
		\	map(range(25, 100, 25), 'dist_max_max * v:val / 100')
		"? let line_distance_to_prev = line_distance_now - line_distance_prev

		" prev: if line_distance_prev >= line_distance_prev * 4
		" prev: 	let [linenum_fwd, linenum_bck] =
		" prev: 		\	[line_start + line_distance_now, line_start - line_distance_now]
		" prev: 	if lineproc_max < line_max
		" prev: 	en
		" prev: 	if lineproc_min > line_min
		" prev: 	en
		" prev: 	"if linenum_fwd < line_max
		" prev: en
		let [linenum_fwd, linenum_bck] = [
			\	min([line_start + line_distance_now, line_max]),
			\	max([line_start - line_distance_now, line_min])]
		" TODO: make sure that this calculation yields the expected behaviour.
		let line_distance_now = max([
			\	(linenum_fwd - line_start),
			\	(line_start - line_min),
			\	])
		" MAYBE: TODO: adjust both linenum_fwd, linenum_bck based on line_distance_now
		" TODO: when an element with the same options is the last one in the
		" array, then we can safely delete that and leave the one we're adding
		" now.
		let should_proc_val_basedondistance = 
			\	(line_distance_now >= line_distance_prev * 4)
		if (linenum_fwd > lineproc_max) && (
				\	(should_proc_val_basedondistance ||
				\	(linenum_fwd == line_max)))
			cal add(searchparams_list, ['', linenum_fwd])
			let lineproc_max = linenum_fwd
		en
		if (linenum_bck < lineproc_min) && (
				\	(should_proc_val_basedondistance ||
				\	(linenum_bck == line_min)))
			cal add(searchparams_list, ['b', linenum_bck])
			let lineproc_min = linenum_bck
		en
		" avoid unnecessary iterations and exit the loop now if there's nothing
		" more to be done.
		if (lineproc_min == line_min) && (lineproc_max == line_max)
			brea
		en

		let line_distance_prev = line_distance_now
	endfo
	cal ctrlp#ev_log_printf(
		\	'%s calculated searchparams_list. ' .
		\		'searchparams_list=%s;',
		\	log_pref, string(searchparams_list))

	let searchresults_dict = {}
	for [search_opt_now, search_stopline_now] in searchparams_list
		" workaround dictionary key (value) limitation: force a non-empty key
		" value.
		let searchresults_key_now = 'opts:' . search_opt_now
		" If we've already found a result for the current search options value, it
		" means that we're now going to search in a bigger range, and thus the
		" closest match in this direction has already been seen.
		" It also means that whatever chance the other(s) options values had of
		" matching, they have passed already, and so there is no point in
		" iterating with regards to those, either.
		if has_key(searchresults_dict, searchresults_key_now) | brea | en
		let line_searchres = search(
			\	a:pattern, search_opt_pref . search_opt_now, search_stopline_now)
		" prev: if line_searchres > 0
		" prev: 	" prev: cal ctrlp#ev_log_printf(
		" prev: 	" prev: 	\	'%s found pattern. about to move cursor to matching line. ' .
		" prev: 	" prev: 	\		'line_found=%d; search_opt_now=%s; stopline_now=%d;',
		" prev: 	" prev: 	\	log_pref,
		" prev: 	" prev: 	\	line_searchres, string(search_opt_now), search_stopline_now)
		" prev: 	" prev: " move cursor to beginning of matching expression, for added
		" prev: 	" prev: " convenience.
		" prev: 	" prev: exe s:accepttag_movetobufcur_nojumps_cmd_pref line_searchres .
		" prev: 	" prev: 	\	' | normal! 0'
		" prev: 	" prev: cal search(a:pattern, 'cW', line_searchres)
		" prev: 	" prev: cal ctrlp#ev_log_printf('%s returning !0.', log_pref)
		" prev: 	" prev: retu !0
		" prev: 	cal ctrlp#ev_log_printf(
		" prev: 		\	'%s found pattern. about to store match data. ' .
		" prev: 		\		'line_found=%d; search_opt_now=%s; stopline_now=%d;',
		" prev: 		\	log_pref,
		" prev: 		\	line_searchres, string(search_opt_now), search_stopline_now)
		" prev: 	let searchresults_dict[searchresults_key_now] = line_searchres
		" prev: en
		if line_searchres <= 0 | con | en
		cal ctrlp#ev_log_printf(
			\	'%s found pattern. about to store match data. ' .
			\		'line_found=%d; search_opt_now=%s; stopline_now=%d;',
			\	log_pref,
			\	line_searchres, string(search_opt_now), search_stopline_now)
		let searchresults_dict[searchresults_key_now] = line_searchres
	endfo
	if empty(searchresults_dict)
		cal ctrlp#ev_log_printf('%s pattern not found. returning 0.', log_pref)
		retu 0
	en

	cal ctrlp#ev_log_printf(
		\	'%s finished searching for pattern. about to calculate best match. ' .
		\		'len(searchresults_dict)=%d; searchresults_dict=%s;',
		\	log_pref,
		\	len(searchresults_dict), string(searchresults_dict))
	" find the match closest to line_start.
	" NOTE: match_distance_min's initial value is set so that the first
	" iteration would cause actual values to be set to both the variables
	" initialised below this line.
	let [match_distance_min, match_line] = [line_max + 1, line_min - 1]
	for match_line_now in values(searchresults_dict)
		let match_distance_now = ctrlp#utils#abs(match_line_now - line_start)
		" if this is a "better" (or equally as good) match as the best we had up
		" until now...
		if (match_distance_now < match_distance_min)
				\	|| ((match_distance_now == match_distance_min)
				\			&& (match_line_now >= match_line))
			" prev: let match_distance_min = match_distance_now
			" prev: let match_line = match_line_now
			let [match_distance_min, match_line] =
				\	[match_distance_now, match_line_now]
		en
	endfo

	en " impl_use_searchparams_list_flag

	" MAYBE: make sure that match_line >= line_min
	cal ctrlp#ev_log_printf(
		\	'%s calculated best match. about to move cursor to matching line. ' .
		\		'line_bestmatch=%d; distance_bestmatch=%d;',
		\	log_pref, match_line, match_distance_min)
	" move cursor to beginning of matching expression, for added
	" convenience.
	exe s:accepttag_movetobufcur_nojumps_cmd_pref match_line .
		\	' | normal! 0'
	cal search(a:pattern, 'cW', match_line)
	cal ctrlp#ev_log_printf('%s returning !0.', log_pref)
	retu !0
endf

" parameters:
"
" * kwargs: dictionary with keyword-named parameters:
"
"		* 'mode' (required): usually the value available in the
"			ctrlp#{module}#accept() function;
"
"		The following can be sometimes obtained through 'taglist()':
"
"		* 'name' (required)
"
"		* 'filename': alternatively, a 'bufnr' entry can be used instead;
"
"		* 'cmd' (optional): used as a first element in the 'gototag_data' list:
"			{ 'set_cmd': VALUE };
"			" prev: * 'cmd', 'search_string', 'lineno'
"
"		non-'taglist()' result members can be specified, too:
"
"		* 'pos_on_notfound' (optional): one of:
"
"			* 'go_back' (default): go back to the original place that the
"				destination window had at the point of entry;
"
"			* 'stay_target_file': stay in the original cursor position in the target
"				file;
"
"			* 'stay_best_effort': stay as close to the target as possible;
"
"		* 'action_on_notfound' (optional): one of:
"
"			* 'return_code' (default): return zero if the tag definition could not
"				be found using the provided data;
"
"			* 'exception': throw an exception if the function could not accurately
"				get to the tag definition using the provided data;
"
"		* 'gototag_data': either a string ('default', in which case the list is
"			retrieved from a global configuration variable), or a list with one or
"			more of the following:
"
"			* 'set_cmd': override the 'cmd' field set in the top-level dictionary;
"				[ 'set_cmd', COMMAND ]
"
"			* 'set_searchstring': use this in the 'post_search_nearby' instead of a
"				calculated search string based on the 'cmd' ('set_cmd');
"				As per standard ':h tag-search' operations, the search string is used
"				as if 'magic' is not set (':set nomagic').
"
"			* 'findtag_tagcmd': use tag command (':tag' and similar);
"
"			* 'findtag_execmd': manually execute the 'cmd' to get to the tag;
"
"			* 'post_search_nearby': search around the line that was deemed as the
"				best candidate for an "exact-ish" match;
"
"			* 'post_execmd': execute the 'cmd' after finding the tag -- if it has
"				found it;
"
fu! ctrlp#tagutils#accept_tag(kwargs) abort
	let log_pref = 'ctrlp#tagutils#accept_tag():'
	let except_pref = log_pref

	let mode = a:kwargs['mode']
	let fname_orig = get(a:kwargs, 'filename', '')
	let tagidentifier = get(a:kwargs, 'name', '')
	let bufnr_orig = get(a:kwargs, 'bufnr', -1)
	" prev: let tagfindcmd_current = get(a:kwargs, 'cmd', '')
	let gototag_curval_cmd = get(a:kwargs, 'cmd', '')
	let pos_on_notfound = get(a:kwargs, 'pos_on_notfound', 'go_back')
	let action_on_notfound = get(a:kwargs, 'action_on_notfound', 'return_code')
	let gototag_data_orig = get(a:kwargs, 'gototag_data', '')
	" MAYBE: add a 'kwargs' and either get the flags directly, or map a
	" user-friendly string value to a set of sensible flags for each possible
	" "enum" value.
	let start_funcflags = 'ja'
	let start_funcflags_restore = start_funcflags . 'A'

	let env_on_entry_dict = copy(ctrlp#get_last_invocation_env())

	let [onentry_bufnr, onentry_curpos] =
		\	[env_on_entry_dict['crbufnr'], env_on_entry_dict['crcursor']]
	" default "start" position (base from which to go to the tag definition).
	let [start_bufnr, start_curpos] = [onentry_bufnr, onentry_curpos]
	" prev: " default "go back" position
	" prev: let [restorepos_start_bufnr, restorepos_start_curpos] =
	" prev: 	\	[onentry_bufnr, onentry_curpos]
	" prev: cal ctrlp#ev_log_printf(
	" prev: 	\	'%s entered. ' .
	" prev: 	\		'kwargs=%s; mode=%s; fname_orig=%s; tagidentifier=%s; ' .
	" prev: 	\		'bufnr_orig=%d; pos_on_notfound=%s; action_on_notfound=%s; ' .
	" prev: 	\		'gototag_data_orig=%s; gototag_curval_cmd=%s; ' .
	" prev: 	\		'start_bufnr=%d; start_curpos=%s; start_funcflags=%s; ' .
	" prev: 	\		'onentry_bufnr=%d; onentry_curpos=%s; ' .
	" prev: 	\		'restorepos_start_bufnr=%d; restorepos_start_curpos=%s;',
	" prev: 	\	log_pref,
	" prev: 	\	string(a:kwargs), string(mode), string(fname_orig), string(tagidentifier),
	" prev: 	\	bufnr_orig, string(pos_on_notfound), string(action_on_notfound),
	" prev: 	\	string(gototag_data_orig), string(gototag_curval_cmd),
	" prev: 	\	start_bufnr, string(start_curpos), string(start_funcflags),
	" prev: 	\	onentry_bufnr, string(onentry_curpos),
	" prev: 	\	restorepos_start_bufnr, string(restorepos_start_curpos))
	cal ctrlp#ev_log_printf(
		\	'%s entered. ' .
		\		'kwargs=%s; mode=%s; fname_orig=%s; tagidentifier=%s; ' .
		\		'bufnr_orig=%d; pos_on_notfound=%s; action_on_notfound=%s; ' .
		\		'gototag_data_orig=%s; gototag_curval_cmd=%s; ' .
		\		'start_bufnr=%d; start_curpos=%s; start_funcflags=%s; ' .
		\		'onentry_bufnr=%d; onentry_curpos=%s;',
		\	log_pref,
		\	string(a:kwargs), string(mode), string(fname_orig), string(tagidentifier),
		\	bufnr_orig, string(pos_on_notfound), string(action_on_notfound),
		\	string(gototag_data_orig), string(gototag_curval_cmd),
		\	start_bufnr, string(start_curpos), string(start_funcflags),
		\	onentry_bufnr, string(onentry_curpos))

	if bufnr_orig > 0
		let bufnr = bufnr_orig
	elsei !empty(fname_orig)
		" NOTE: this will be -1 (< 0) for (yet) unopened files.
		let bufnr = bufnr(fname_orig)
		" NOTE: this variable gets overwritten later.
		"
		" MAYBE: have some logic to *not* use the starting position on
		" 'fname_orig' as the starting point, and use the buffer+cursor on entry
		" instead.
		"  NOTE: for that, we might have to use the technique for keeping the
		"  newly opened file (after ctrlp#acceptfile()) open in a new tab (at the
		"  end, to avoid altering the tab numbering, and also with 'noautocmd',
		"  etc.), then proceed with the whole "find the tag" algorithm, and revert
		"  the local changes by closing that last tab, too.
		"   NOTE: we'll want to avoid closing the wrong tab by "tagging" the tab
		"   with a tab variable ('t:').
		"    IDEA: put this logic of opening a buffer/file in a temporary tab,
		"    then reverting those changes in either:
		"     IDEA #1: a function that calls a callback in a 'try .. finally'
		"     block;
		"     IDEA #2: (might be more natural for vim script, as it does not have
		"     closures) have a function to start the process, return an opaque
		"     object (a dictionary describing what it's done, for example
		"     including the value for the tab variable), and another function to
		"     "revert" those actions (to be put in a 'finally' block).
	el
		throw printf(
			\	'%s unspecified/invalid kwargs.%s: empty value',
			\	except_pref, string('filename'))
	en
	if empty(fname_orig)
		let fname_orig = bufname(bufnr)
	en
	" get rid of issues caused by having different current directories between
	" the entry point and the point at which the filename is used (which could
	" result in a different absolute pathname being computed).
	let fname_orig_full = fnamemodify(fname_orig, ':p')

	let stateflag_found_tag = 0
	let stateflag_intargetwin = 0
	let stateflag_post_searchnearby_done = 0

	" process input arguments:
	"  pos_on_notfound
	if index(['go_back', 'stay_target_file', 'stay_best_effort'], pos_on_notfound) < 0
		let except_reason = printf('value %s is not supported', string(pos_on_notfound))
		throw printf(
			\	'%s validating kwargs.%s: %s',
			\	except_pref, 'pos_on_notfound', except_reason)
	en

	"  action_on_notfound
	if index(['return_code', 'exception'], action_on_notfound) < 0
		let except_reason = printf('value %s is not supported', string(action_on_notfound))
		throw printf(
			\	'%s validating kwargs.%s: %s',
			\	except_pref, 'action_on_notfound', except_reason)
	en

	"  gototag_data_orig:
	let gototag_data_orig_type = type(gototag_data_orig)
	if (gototag_data_orig_type == s:typeid_str) && empty(gototag_data_orig)
		let gototag_data_orig = 'default'
	en
	if (gototag_data_orig_type == s:typeid_str) && (gototag_data_orig ==# 'default')
		let gototag_data_orig = get(
			\	g:, 'ctrlp_tagutils_accepttag_seq', 'findtag_tagcmd,findtag_execmd')
	en
	if (gototag_data_orig_type == s:typeid_str)
		let gototag_data_list = split(gototag_data_orig, ',')
	elsei (gototag_data_orig_type == s:typeid_list)
		let gototag_data_list = copy(gototag_data_orig)
	el
		throw printf(
			\	'%s kwargs.gototag_data type unsupported. type=%s; value=%s;',
			\	except_pref, string(gototag_data_orig_type), string(gototag_data_orig))
	en
	"  MAYBE: do the validation in the processing loop, allowing the skipping of
	"  unnecessary actions (once we've succeeded in getting to the tag
	"  definition).
	" IDEA: use this (later?) to validate and extract operation parameters at once
	" prev: let validator_expr_nonempty = '!empty(v:val)'
	" prev: "+? let validator_expr_every_arg_nonempty =
	" prev: "+? 	\	'empty(filter(copy(v:val),''empty(v:val)''))'
	" prev: let validator_expr_only_one_nonempty_arg =
	" prev: 	\	'((len(v:val) == 1) && (!empty(v:val[0])))'
	" prev: let validator_expr_printf_arg_d_type_d =
	" prev: 	\ '(type(v:val[ %d ]) == %d)'
	" prev: let validator_expr_arg_0_is_string = printf(
	" prev: 	\	validator_expr_printf_arg_d_type_d, 0, s:typeid_str)
	" prev: let validator_expr_only_one_nonempty_string = printf(
	" prev: 	\	'( %s ) && ( %s )',
	" prev: 	\	validator_expr_only_one_nonempty_arg,
	" prev: 	\	validator_expr_arg_0_is_string)
	" prev: " TODO: implement variable
	" prev: " prev: let precond_expr_has_cmd = '!empty(tagfindcmd_current)'
	" prev: let precond_expr_has_cmd = '!empty(gototag_curval_cmd)'
	" prev: " TODO: implement variable
	" prev: let precond_expr_at_dst_tag = 'found_tag_flag'
	" TODO: implement every single key+value defined below
	" prev: let gototag_data_items_def_dict = {
	" prev: 	\		'set_cmd': {
	" prev: 	\				'arg_policy': 'req',
	" prev: 	\				'arg_allowed_types_MAYBE_1': [s:typeid_list],
	" prev: 	\				'arg_allowed_types': [s:typeid_str],
	" prev: 	\				'arg_validator_expr_PREV_TOBEREMOVED_1': validator_expr_nonempty,
	" prev: 	\				'arg_validator_expr_PREV_TOBEREMOVED_2': validator_expr_only_one_nonempty_arg,
	" prev: 	\				'arg_validator_expr_MAYBE_1': validator_expr_only_one_nonempty_string,
	" prev: 	\				'arg_validator_expr': validator_expr_nonempty,
	" prev: 	\			},
	" prev: 	\		'set_searchstring': {
	" prev: 	\				'arg_policy': 'req',
	" prev: 	\				'arg_allowed_types_MAYBE_1': [s:typeid_list],
	" prev: 	\				'arg_allowed_types': [s:typeid_str],
	" prev: 	\				'arg_validator_expr_PREV_TOBEREMOVED_1': validator_expr_nonempty,
	" prev: 	\				'arg_validator_expr_PREV_TOBEREMOVED_2': validator_expr_only_one_nonempty_arg,
	" prev: 	\				'arg_validator_expr_MAYBE_1': validator_expr_only_one_nonempty_string,
	" prev: 	\				'arg_validator_expr': validator_expr_nonempty,
	" prev: 	\			},
	" prev: 	\		'findtag_tagcmd': {
	" prev: 	\				'arg_policy_THIS_IS_THE_DEFAULT_NOW': 'none',
	" prev: 	\				'precond_expr_MAYBE_IMPLIED_FROM_ITEM_TYPE': precond_expr_has_cmd,
	" prev: 	\				'item_type': 'itemtype_find_tag',
	" prev: 	\			},
	" prev: 	\		'findtag_execmd': {
	" prev: 	\				'arg_policy_THIS_IS_THE_DEFAULT_NOW': 'none',
	" prev: 	\				'precond_expr_MAYBE_IMPLIED_FROM_ITEM_TYPE': precond_expr_has_cmd,
	" prev: 	\				'item_type': 'itemtype_find_tag',
	" prev: 	\			},
	" prev: 	\		'post_search_nearby': {
	" prev: 	\				'arg_policy': 'opt',
	" prev: 	\				'arg_allowed_types': [s:typeid_str],
	" prev: 	\				'arg_validator_expr': validator_expr_nonempty,
	" prev: 	\				'precond_expr_MAYBE_IMPLIED_FROM_ITEM_TYPE': precond_expr_at_dst_tag . ' && ( ( ' . precond_expr_has_cmd . ' ) || ( SEARCH_STRING_NOT_EMPTY ) )',
	" prev: 	\				'item_type': 'itemtype_tagfound_post',
	" prev: 	\			},
	" prev: 	\		'post_execmd': {
	" prev: 	\				'arg_policy_THIS_IS_THE_DEFAULT_NOW': 'none',
	" prev: 	\				'precond_expr_MAYBE_IMPLIED_FROM_ITEM_TYPE': precond_expr_has_cmd,
	" prev: 	\				'item_type': 'itemtype_tagfound_post',
	" prev: 	\			},
	" prev: 	\ }
	try
		let check_done = 0
		let res_disallowed_values = filter(
			\	map(
			\		copy(gototag_data_list),
			\		'(type(v:val) == s:typeid_list) ? get(v:val, 0, "") : v:val'),
			\	'!has_key(s:gototag_data_items_def_dict, v:val)')
		let check_done = !0

	fina
		unl! except_reason
		if !check_done
			let except_reason = 'exception caught when validating input values'
		elsei !empty(res_disallowed_values)
			let except_reason = 'the following values are not supported: ' .
				\	join(map(sort(copy(res_disallowed_values)), 'string(v:val)'), ', ')
		en
		if exists('except_reason')
			throw printf('%s validating kwargs.%s: %s', except_pref, 'gototag_data', except_reason)
		en

	endt

	let saved_exprs_search_list = [
		\		['sav_magic', '&magic', 0],
		\		['sav_hlsearch', '&hlsearch', 0],
		\		['sav_searchregister', '@/'],
		\	]

	let dataid_to_varnames_dict = {
		\	'gtd_dataid_cmd': {
		\			'varname_procflag': 'proc_usetagcmd_flag',
		\			'varname_value': 'gototag_curval_cmd',
		\		},
		\	'gtd_dataid_pattern': {
		\			'varname_procflag': 'proc_usesrchstr_flag',
		\			'varname_value': 'gototag_curval_searchstring',
		\		},
		\	'gtd_dataid_searchstartpos': {
		\			'varname_procflag': 'proc_usesearchstartpos_flag',
		\			'varname_value': 'gototag_curval_searchstartpos',
		\		},
		\	'gtd_dataid_nearbymaxdist': {
		\			'varname_procflag': 'proc_usenearbymaxdist_flag',
		\			'varname_value': 'gototag_curval_nearbymaxdist',
		\		},
		\	}

	" TODO: remove comment
	" not_done: if the tag was not found (or some other condition, too?), go back
	" to the start by injecting a last entry in gototag_data_list to that
	" effect.
	"  done: or put the "goto start" in a function, and call that from more than
	"  one point within this function.

	" make each element into a list, to ease processing inside the loop
	let gototag_data_list = map(
		\	gototag_data_list,
		\	'(type(v:val) == s:typeid_list) ? v:val : [v:val]')
	" prev: " prev: let [gototag_curval_cmd, gototag_curval_searchstring] = ['', '']
	" prev: let gototag_curval_searchstring = ''
	let [gototag_curval_searchstring, gototag_curval_searchstartpos] =
		\	['', [0, -1, 0, 0]]
	" default: -1 means "search as far as possible".
	let gototag_curval_nearbymaxdist = -1
	let tmpfile_tags = ''
	let stateflag_proc_error = 0
	try
		" ref: s:gototag_data_items_def_dict
		for gototag_item in gototag_data_list
			if stateflag_proc_error
				if !exists('proc_error_desc') || empty(proc_error_desc)
					" TODO: throw exception: this flag was set and the loop wasn't
					" aborted.
					let except_reason =
						\	'internal error: ' .
						\	'stateflag_proc_error set and proc_error_desc unset/empty.'
				en
				brea
			en
			" prev: " prev: if empty(gototag_item)
			" prev: if empty(gototag_item)
			" prev: 	let except_reason = printf(
			" prev: 		\	'kwargs.%s: list item is invalid/unsupported: %s',
			" prev: 		\	'gototag_data', string(gototag_item))
			" prev: 	brea
			" prev: en
			unl! gototag_item_verb gototag_item_def
				\	gototag_item_type
				\	gototag_item_arg item_arg_policy item_arg_validator_expr
				\	gototag_item_arg_types_allowed gototag_item_arg_type
				\	proc_error_desc
			" NOTE: ':unlet!' not strictly needed -- commented-out for now
			"? unl! gototag_item_dstvarname proc_varname_now proc_usedataid_now

			let gototag_item_verb = get(gototag_item, 0, '')
			let gototag_item_def =
				\	get(s:gototag_data_items_def_dict, gototag_item_verb)

			if empty(gototag_item_def)
				let except_reason = printf(
					\	'kwargs.%s: list item is invalid/unsupported: %s',
					\	'gototag_data', string(gototag_item))
				brea
			en
			cal ctrlp#ev_log_printf(
				\	'%s about to start processing gototag_item. ' .
				\		'gototag_item=%s; gototag_item_def=%s;',
				\	log_pref, string(gototag_item), string(gototag_item_def))

			let gototag_item_type = get(gototag_item_def, 'item_type', '')
			let item_arg_policy = get(gototag_item_def, 'arg_policy', 'none')
			" NOTE: empty(s:internal_obj_ref) is true
			let gototag_item_arg = get(gototag_item, 1, s:internal_obj_ref)
			if (gototag_item_arg is s:internal_obj_ref)
				unl gototag_item_arg
			en
			"? if !(empty(gototag_item_arg) == (item_arg_policy ==# 'none'))
			" prev: if !((gototag_item_arg is s:internal_obj_ref)
			" prev: 		\	== (item_arg_policy ==# 'none'))
			"-? if !((gototag_item_arg is s:internal_obj_ref)
			"-? 		\	== (index(['none', 'opt'], item_arg_policy) >= 0))
			if !(
					\	(!(item_arg_policy ==# 'none')) || (!exists('gototag_item_arg'))
					\	&&
					\	(!(item_arg_policy ==# 'req')) || (exists('gototag_item_arg'))
					\	)
				let except_reason = printf(
					\	'kwargs.%s: list item has the wrong number of args. ' .
					\		'arg_policy=%s; item=%s;',
					\	'gototag_data', string(item_arg_policy), string(gototag_item))
				brea
			en

			if exists('gototag_item_arg')
				let gototag_item_arg_types_allowed = get(
					\ gototag_item_def, 'arg_allowed_types', s:internal_obj_ref)
				if gototag_item_arg_types_allowed isnot s:internal_obj_ref
					let gototag_item_arg_type = type(gototag_item_arg)
					if index(gototag_item_arg_types_allowed, gototag_item_arg_type) < 0
						let except_reason = printf(
							\	'kwargs.%s: item arg type is not supported. ' .
							\		'arg_types_allowed=%s; arg_type=%d; item=%s;',
							\	'gototag_data', string(gototag_item_arg_types_allowed),
							\	gototag_item_arg_type, string(gototag_item))
						brea
					en
				en

				let item_arg_validator_expr =
					\	get(gototag_item_def, 'arg_validator_expr')
				if !empty(item_arg_validator_expr)
					try
						"? sandbox let sucflag = !!eval(item_arg_validator_expr)
						sandbox let sucflag = !empty(filter(
							\	[gototag_item_arg], item_arg_validator_expr))
					cat
						let sucflag = 0
					endt
					if !sucflag
						let except_reason = printf(
							\ '%s arg validation has failed: ' .
							\		'gototag_item=%s; validator=%s;',
							\	except_pref,
							\	string(gototag_item), string(item_arg_validator_expr))
						brea
					en
				en
			en

			let procflag = 1
			" prev: let [proc_gotostart_flag, proc_usetagcmd_flag, proc_usesrchstr_flag] =
			" prev: 	\	[0, 0, 0]
			" initialise all the 'proc_*' variables.
			let proc_gotostart_flag = 0
			" prev: for proc_varname_now in values(dataid_to_varname_dict)
			for proc_varname_now in map(
					\	values(dataid_to_varnames_dict),
					\	'v:val[ ''varname_procflag'' ]')
				let {proc_varname_now} = 0
			endfo
			" and set the ones present in (the) 'uses_dataids' (dictionary entry).
			for proc_usedataid_now in get(gototag_item_def, 'uses_dataids', [])
 				" prev: let {dataid_to_varname_dict[proc_usedataid_now]} = 1
 				let {dataid_to_varnames_dict[proc_usedataid_now]['varname_procflag']} =
					\	1
			endfo

			if procflag
				if gototag_item_type ==# 'itemtype_find_tag'
					let procflag = !stateflag_found_tag
				elsei gototag_item_type ==# 'itemtype_tagfound_post'
					let procflag = stateflag_found_tag
					if gototag_item_verb ==# 'post_search_nearby'
						let procflag = procflag && (!stateflag_post_searchnearby_done)
					en
				en
			en

			if procflag
				if gototag_item_type ==# 'itemtype_find_tag'
					" save current position, optionally jump to the dest file, etc.
					if !stateflag_intargetwin
						" this might create an entry in the 'jumplist'.
						"-? cal ctrlp#acceptfile(mode, bufnr)
						"-? " FIXME: when opening a file gives a warning, this aborts
						"-? cal ctrlp#acceptfile(mode, (bufnr > 0 ? bufnr : fname_orig))
						"-? let bufnr_now = bufnr('%')
						"-? " as soon as we've moved to the target tab/window + buffer, we will
						"-? " try to move to a suitable "starting position"
						"-? if ctrlp#istablayoutsnapshotsameasonentry({
						"-? 	\	'ignored_fields': 'tablysnapcomp_samewinfocused',
						"-? 	\	}) && (bufnr_now != env_on_entry_dict['crbufnr'])
						"-? 	" get the starting position from what we've saved when ctrlp was
						"-? 	" activated.
						"-? 	let start_bufnr = env_on_entry_dict['crbufnr']
						"-? 	let start_curpos = env_on_entry_dict['crcursor']
						"-? 	"? " MAYBE: flag as needing the 'jumplist'
						"-? el
						"-? 	" get the starting position from where we are now.
						"-? 	let start_bufnr = bufnr_now
						"-? 	let start_curpos = ctrlp#utils#getcurpos()
						"-? en
						"? let bufnr_existing = (bufnr > 0) ? bufnr :
						"?  \	bufnr(fnamemodify(fname_orig, ':p'))
						" NOTE: this could be -1 for unloaded(/wiped?)/unavailable buffers.
						let bufnr_existing = (bufnr > 0) ? bufnr :
							\	bufnr('^' . fname_orig_full . '$')
						unl! proc_savebufnrexistingpos_flag
						if bufnr_existing > 0
							" for now, we will only consider the "current" position on the
							" "target" (/"dest") buffer if that buffer was listed.
							" NOTE: for example, if the ':jumps' command is executed, vim
							" loads the buffers and then marks them as '!&l:buflisted', so
							" their "current" position should not be considered.
							let proc_savebufnrexistingpos_flag =
								\ ctrlp#utils#getbufvar(
								\		bufnr_existing, '&l:buflisted', s:typeid_num)
						en

						cal ctrlp#ev_log_printf(
							\	'%s about to call ctrlp#acceptfile(): ' .
							\		'mode=%s; bufnr=%d; fname_orig=%s; bufnr_existing=%d;',
							\	log_pref, string(mode), bufnr, string(fname_orig),
							\	bufnr_existing)
						try
							cal ctrlp#acceptfile(mode, (bufnr > 0 ? bufnr : fname_orig))
							" MAYBE: validate against bufnr_existing

						cat
							" handles the file being opened by another vim instance, etc.
							" for now, we do nothing in particular, and we just check that
							" we've switched to the desired buffer/file.

						fina
							let bufnr_now = bufnr('%')
							" manually determine whether we could still open the desired
							" bufnr/fname_orig.
							let sucflag = (bufnr > 0) ? (bufnr_now == bufnr) :
								\	(fnamemodify(bufname(bufnr_now), ':p') ==# fname_orig_full)
							if !sucflag
								let except_reason = printf(
									\ '%s file/buffer could not be opened/activated: ' .
									\		'bufnr=%d; fname_orig=%s; fname_orig_full=%s; ' .
									\		'bufnr_now=%d; bufname_now=%s;',
									\	except_pref,
									\	bufnr, string(fname_orig), string(fname_orig_full),
									\	bufnr_now, string(bufname(bufnr_now)))
								brea
							en
						endt
						let curpos_now = ctrlp#utils#getcurpos()

						" save the "entry" (/"start") point to(/in) the "target" (/"dest")
						" buffer/file.
						let [restorepos_tgt_bufnr, restorepos_tgt_curpos] =
							\	[bufnr_now, curpos_now]
						cal ctrlp#ev_log_printf(
							\	'%s saved starting buffer+position in target buffer/file. ' .
							\		'restorepos_tgt_bufnr=%d; restorepos_tgt_curpos=%s;',
							\	log_pref,
							\	restorepos_tgt_bufnr, string(restorepos_tgt_curpos))

						" MAYBE: let restorepos_tgt_bufnr = bufnr_now | let restorepos_tgt_curpos = curpos_now (TODO: implement)
						"  IDEA: log those new variables here, too
						"  IDEA: and use curpos_now instead of ctrlp#utils#getcurpos()
						"		just below, too.

						if (bufnr_existing > 0) && proc_savebufnrexistingpos_flag
							let start_funcflags_now = start_funcflags . 'Ja'
							if !ctrlp#tagutils#gobacktostartpos(
									\	0, 0, start_funcflags_now)
								let stateflag_proc_error = !0
								let proc_error_desc = printf(
									\		'could not mark the current position ' .
									\			'in the jumplist. ' .
									\			'bufnr=%d; curpos=%s; start_funcflags=%s; ' .
									\			'fname_orig_full=%s;',
									\		bufnr_existing, string('<current>'),
									\		string(start_funcflags_now),
									\		string(fname_orig_full))
								brea
							en
							" as we're going to store the current position in the "target"
							" file, we won't be searching for previous entries in the
							" jumplist: we'll create new ones at the current jumplist
							" position.
							let start_funcflags .= 'J'
						en

						" TODO: IDEA: detect whether the destination bufnr/fname_orig
						" existed before "switching" to it, so we can decide to use that
						" position as the last one *before* the starting point for the
						" destination tab+window.  That is, there will be a consistent
						" post-condition which is:
						"		* for found tag:
						"
						"			* current cursor position is at the top of the tags stack;
						"
						"			* current cursor position is the current entry in the
						"				jumplist;
						"
						"			* the previous entry in both the tags stack and the jumplist
						"				will be the bufnr+cusror_position at the point at which
						"				ctrlp was invoked (available in 'env_on_entry_dict' here).
						"
						"			* if the file existed before entering this function, then
						"				that position will be available in the jumplist as the one
						"				just before the point of entry to ctrlp.  Thus the
						"				jumplist will be (oldest to most recent, just like
						"				':jumps' produces):
						"
						"					*	original_cusros_pos_in_target_buffer
						"
						"					*	starting point (at which ctrlp was invoked from the
						"						original buffer;
						"
						"					* position as resulting from finishing the
						"						'gototag_data' parameter;
						"
						" prev: " as soon as we've moved to the target tab/window + buffer, we will
						" prev: " try to move to a suitable "starting position"
						" prev: if ctrlp#istablayoutsnapshotsameasonentry({
						" prev: 	\	'ignored_fields': 'tablysnapcomp_samewinfocused',
						" prev: 	\	}) && (bufnr_now != env_on_entry_dict['crbufnr'])
						" prev: 	" get the starting position from what we've saved when ctrlp was
						" prev: 	" activated.
						" prev: 	let start_bufnr = env_on_entry_dict['crbufnr']
						" prev: 	let start_curpos = env_on_entry_dict['crcursor']
						" prev: 	"? " MAYBE: flag as needing the 'jumplist'
						" prev: el
						" prev: 	" get the starting position from where we are now.
						" prev: 	let start_bufnr = bufnr_now
						" prev: 	let start_curpos = ctrlp#utils#getcurpos()
						" prev: en
						"
						" prev: " as soon as we've moved to the target tab/window + buffer, we will
						" prev: " try to move to a suitable "starting position"
						" prev: if !ctrlp#istablayoutsnapshotsameasonentry({
						" prev: 	\	'ignored_fields': 'tablysnapcomp_samewinfocused',
						" prev: 	\	})
						" prev: 	" get the "restore" position from where we are now.
						" prev: 	" prev: let [restorepos_start_bufnr, restorepos_start_curpos] =
						" prev: 	" prev: 	\	[bufnr_now, ctrlp#utils#getcurpos()]
						" prev: 	"? let [restorepos_start_bufnr, restorepos_start_curpos] =
						" prev: 	"? 	\	[bufnr_now, curpos_now]
						" prev: 	let [restorepos_start_bufnr, restorepos_start_curpos] =
						" prev: 		\	[restorepos_tgt_bufnr, restorepos_tgt_curpos]
						" prev: 	cal ctrlp#ev_log_printf(
						" prev: 		\	'%s ctrlp#acceptfile() has taken us to ' .
						" prev: 		\		'a different tab/window. setting the restore position ' .
						" prev: 		\		'to be that of the target tab/window. ' .
						" prev: 		\		'restorepos_start_bufnr=%d; restorepos_start_curpos=%s;',
						" prev: 		\	log_pref,
						" prev: 		\	restorepos_start_bufnr, string(restorepos_start_curpos))
						" prev: en
						" prev: "? " ref: let [restorepos_start_bufnr, restorepos_start_curpos] = [onentry_bufnr, onentry_curpos]
						if ctrlp#istablayoutsnapshotsameasonentry({
							\	'ignored_fields': 'tablysnapcomp_samewinfocused',
							\	})
							let [restorepos_start_bufnr, restorepos_start_curpos] =
								\	[onentry_bufnr, onentry_curpos]
							cal ctrlp#ev_log_printf(
								\	'%s ctrlp#acceptfile() has taken us to ' .
								\		'the starting tab/window. ' .
								\		'setting the "start" restore position accordingly. ' .
								\		'restorepos_start_bufnr=%d; restorepos_start_curpos=%s;',
								\	log_pref,
								\	restorepos_start_bufnr, string(restorepos_start_curpos))
						en

						" now that we've opened the file, we've got a bufnr associated to
						" it, so we conditionally save it.  This will become useful later
						" to retrieve the bufname() when we need it, to get the best
						" possible match.
						if !(bufnr > 0)
							let bufnr = bufnr_now
						en
						unl bufnr_now
						let stateflag_intargetwin = !0
					en
					let proc_gotostart_flag = !0
				en
			en

			" prev: if procflag
			" prev: 	if gototag_item_type ==# 'itemtype_tagfound_post'
			" prev: 		" MAYBE: TODO: continue implementing
			" prev: 		if gototag_item_verb ==# 'post_execmd'
			" prev: 			if exists('gototag_item_arg')
			" prev: 				let gototag_curval_cmd = gototag_item_arg
			" prev: 			en
			" prev: 		elsei gototag_item_verb ==# 'post_search_nearby'
			" prev: 			if exists('gototag_item_arg')
			" prev: 				let gototag_curval_searchstring = gototag_item_arg
			" prev: 			en
			" prev: 		en
			" prev: 	elsei gototag_item_verb ==# 'set_cmd'
			" prev: 		let gototag_curval_cmd = gototag_item_arg
			" prev: 	elsei gototag_item_verb ==# 'set_searchstring'
			" prev: 		let gototag_curval_searchstring = gototag_item_arg
			" prev: 	en
			" prev: en
			" assign the (optional/required) value to the variable (as per
			" 'dataid_to_varname_dict') that this verb specifies (in
			" 's:gototag_data_items_def_dict')
			if procflag && exists('gototag_item_arg')
				" NOTE: on vim-7.0: get({}, '', 'def') -> 'def'
				" prev: "- let gototag_item_dstvarname =
				" prev: "- 	\	get(
				" prev: "- 	\		dataid_to_varname_dict,
				" prev: "- 	\		get(gototag_item_def, 'sets_dataid', ''),
				" prev: "- 	\		'')
				" prev: let gototag_item_dstvarname =
				" prev: 	\	get(
				" prev: 	\		get(
				" prev: 	\			dataid_to_varnames_dict,
				" prev: 	\			get(gototag_item_def, 'sets_dataid', ''),
				" prev: 	\			{}),
				" prev: 	\	'varname_value', '')
				unl! gototag_item_dstvarname
				let gototag_item_dataid_set = get(gototag_item_def, 'sets_dataid', '')
				if !empty(gototag_item_dataid_set)
					let gototag_item_dstvarname =
						\	get(
						\		get(dataid_to_varnames_dict, gototag_item_dataid_set, {}),
						\		'varname_value', '')
				en

				" prev: if !empty(gototag_item_dstvarname)
				if exists('gototag_item_dstvarname') && !empty(gototag_item_dstvarname)
					unl! gototag_item_srcval
					" handle special cases (which could also be handled as expression
					" entries in dataid_to_varnames_dict, for example).
					if gototag_item_dataid_set ==# 'gtd_dataid_searchstartpos'
						" prev: " prev: \	?	[0, (gototag_item_arg > 0 ? ... : ...), 1, 0]
						" prev: let gototag_item_srcval =
						" prev: 	\	(type(gototag_item_arg) == s:typeid_num)
						" prev: 	\	?	[0, gototag_item_arg, 1, 0]
						" prev: 	\	:	deepcopy(gototag_item_arg)
						" TODO: when optionally setting the cursor position, handle the
						" line number being <= 0, and do nothing in that case.
						let gototag_item_srcval =
							\	(type(gototag_item_arg) == s:typeid_num)
							\	?	[0, gototag_item_arg, 1, 0]
							\	:	gototag_item_arg[0:3]
						let [gototag_item_srcval[0], gototag_item_srcval[3]] = [0, 0]
					el
						" by default, we copy the object reference and assign that to the
						" dst variable.
						let gototag_item_srcval = gototag_item_arg
					en
					" prev: cal ctrlp#ev_log_printf(
					" prev: 	\	'%s setting variable associated to dataid from item arg. ' .
					" prev: 	\		'gototag_item_def=%s; ' .
					" prev: 	\		'gototag_item_dstvarname=%s; gototag_item_arg=%s',
					" prev: 	\	log_pref,
					" prev: 	\	string(gototag_item_def),
					" prev: 	\	string(gototag_item_dstvarname),
					" prev: 	\	string(gototag_item_arg))
					" prev: let {gototag_item_dstvarname} = gototag_item_arg
					cal ctrlp#ev_log_printf(
						\	'%s setting variable associated to dataid from item arg. ' .
						\		'gototag_item_def=%s; ' .
						\		'gototag_item_dstvarname=%s; ' .
						\		'gototag_item_arg=%s; gototag_item_srcval=%s;',
						\	log_pref,
						\	string(gototag_item_def),
						\	string(gototag_item_dstvarname),
						\	string(gototag_item_arg),
						\	string(gototag_item_srcval))
					" perform assignment
					let {gototag_item_dstvarname} = gototag_item_srcval
				en
				unl! gototag_item_srcval gototag_item_dstvarname gototag_item_dataid_set
			en

			if procflag && proc_gotostart_flag
				" go to our "starting" position
				" prev: if has('jumplist')
				" prev: 	let cmd_jumplist_jmp_common_pref = 'normal! '
				" prev: 	let cmd_jumplist_jmp_back_suff = "\<c-o>"
				" prev: 	let cmd_jumplist_jmp_fwd_suff = "\<c-i>"
				" prev: 	let [at_startpos, njumps_done] = [0, 0]
				" prev: 	try
				" prev: 		for njumps_done in range(0, 2)
				" prev: 			let cur_curpos = ctrlp#utils#getcurpos()
				" prev: 			let at_startpos = (
				" prev: 				\	(bufnr('%') == start_bufnr)
				" prev: 				\	&& (cur_curpos[1:3] == start_curpos[1:3]))
				" prev: 			if at_startpos | brea | en
				" prev: 			" raising an exception would also keep njumps_done unchanged.
				" prev: 			exe cmd_jumplist_jmp_common_pref .
				" prev: 				\	'1' . cmd_jumplist_jmp_back_suff
				" prev: 			" Detect if this "go to previous entry in the jumplist" has done
				" prev: 			" something.  If it hasn't, then we can't rely on a future
				" prev: 			" njumps_done value being an accurate representation of the
				" prev: 			" number of jumps having been made.
				" prev: 			if cur_curpos == ctrlp#utils#getcurpos() | brea | en
				" prev: 		endfo
				" prev: 	fina
				" prev: 		if (!at_startpos) && (njumps_done > 0)
				" prev: 			exe cmd_jumplist_jmp_common_pref .
				" prev: 				\	njumps_done . cmd_jumplist_jmp_fwd_suff
				" prev: 		en
				" prev: 	endt
				" prev: en
				" prev: if bufnr('%') != start_bufnr
				" prev: 	exe s:accepttag_switchtostartbuf_cmd_pref 'b' start_bufnr
				" prev: en
				" prev: if cur_curpos[1:3] != start_curpos[1:3]
				" prev: 	" NOTE: from vim-7.0 documentation:
				" prev: 	" setpos(): "does not change the jumplist"
				" prev: 	cal setpos('.', start_curpos)
				" prev: en
				if !ctrlp#tagutils#gobacktostartpos(
						\	start_curpos, start_bufnr, start_funcflags)
					let stateflag_proc_error = !0
					let proc_error_desc = printf(
						\		'could not restore cursor position to the ''start''. ' .
						\			'bufnr=%d; curpos=%s; start_funcflags=%s;',
						\		start_bufnr, string(start_curpos), string(start_funcflags))
					brea
				en
				"-? if !exists('fname_full')
				"-? 	let fname_full = fnamemodify(fname_orig_full, ':.')
				"-? en
			en

			" prev: if procflag
			" prev: 	if gototag_item_type ==# 'itemtype_find_tag'
			" prev: 		if gototag_item_verb ==# 'findtag_tagcmd'
			" prev: 			let proc_usetagcmd_flag = !0
			" prev: 		elsei gototag_item_verb ==# 'findtag_execmd'
			" prev: 			"-? let proc_usesrchstr_flag = !0
			" prev: 			let proc_usetagcmd_flag = !0
			" prev: 		en
			" prev: 	elsei gototag_item_type ==# 'itemtype_tagfound_post'
			" prev: 		if gototag_item_verb ==# 'post_execmd'
			" prev: 			let proc_usetagcmd_flag = !0
			" prev: 		elsei gototag_item_verb ==# 'post_search_nearby'
			" prev: 			let proc_usesrchstr_flag = !0
			" prev: 		en
			" prev: 	en
			" prev: en

			" make sure that we have "current" values for each of the variables
			" associated to "dataid" entries we know about
			" (dataid_to_varnames_dict).
			" perform conversions where needed.
			" NOTE: not needed for now:
			"		* proc_usenearbymaxdist_flag;
			"		* [done] proc_usesearchstartpos_flag;
			" prev: if procflag && (proc_usetagcmd_flag || proc_usesrchstr_flag)
			if procflag
					\	&& (proc_usetagcmd_flag || proc_usesrchstr_flag
					\		|| proc_usesearchstartpos_flag)
				unl! proc_error_desc
				if proc_usetagcmd_flag
						\	&& !(!empty(gototag_curval_cmd))
					let proc_error_desc = 'no ex command has been set'
				en
				if proc_usesrchstr_flag
						\	&& !(!empty(gototag_curval_searchstring))
					let proc_error_desc = 'no search string has been set'
				en
				" not needed for now, as it's always initialised above
				"  if proc_usenearbymaxdist_flag && !(...)
				"-? if proc_usesearchstartpos_flag
				"-? 	unl! gototag_curval_searchstartpos
				"-? 	" FIXME: let gototag_curval_searchstartpos = ... gototag_curval_searchstartpos_orig
				"-? en

				" for now, we skip this step only, so it will gracefully carry on
				if exists('proc_error_desc') && (!empty(proc_error_desc))
					cal ctrlp#ev_log_printf(
						\	'%s %s. gototag_item=%s; ' .
						\		'curval_cmd=%s; curval_searchstring=%s;',
						\	log_pref, proc_error_desc, string(gototag_item),
						\	string(gototag_curval_cmd), string(gototag_curval_searchstring))
					unl proc_error_desc
					" NOTE: instead of: let stateflag_proc_error = !0 | ... | brea
					let procflag = 0
				en
			en

			" NOTE: not needed for now:
			"		* proc_usenearbymaxdist_flag;
			"		* proc_usesearchstartpos_flag;
			"? if procflag
			"? 			\	&& (proc_usetagcmd_flag || proc_usesrchstr_flag
			"? 			\		|| proc_usesearchstartpos_flag)
			if procflag && (proc_usetagcmd_flag || proc_usesrchstr_flag)
				" TODO: LATER: look inside gototag_curval_searchstring (if
				" proc_usesrchstr_flag) and determine whether the string has set its
				" own "magic"-ish flag inside.  A regex might help:
				"		if ... && gototag_curval_searchstring !~#
				"		'\v^%(\\%(%([cCZ])|%(z[se])))*%(\\[vmMV])'
				" prev: if !exists('sav_magic')
				" prev: 	" note: exists('sav_magic') is used as a flag throughout.
				" prev: 	let sav_magic = &magic
				" prev: en
				for [t_sav_varname, t_sav_expr; t_sav_rest_list]
						\	in saved_exprs_search_list
					if exists(t_sav_varname) | con | en
					try
						let {t_sav_varname} = eval(t_sav_expr)
						if empty(t_sav_rest_list) | con | en
						if t_sav_rest_list[0] !=# {t_sav_varname}
							" NOTE: this does not work for '@/'
							"- let {t_sav_expr} = t_sav_rest_list[0]
							exe printf('let %s = %s', t_sav_expr, 't_sav_rest_list[0]')
						en
					cat
						" MAYBE: report/log error
					endt
				endfo
				unl! t_sav_varname t_sav_expr t_sav_rest_list
				" prev: " avoid setting the values unnecessarily
				" prev: if &magic | set nomagic | en
			en

			cal ctrlp#ev_log_printf(
				\	'%s finished assessing whether to execute gototag_item or not. ' .
				\		'gototag_item=%s; ' .
				\		'procflag=%d; ' .
				\		'proc_usetagcmd_flag=%d; proc_usesrchstr_flag=%d; ' .
				\		'proc_usesearchstartpos_flag=%d; proc_usenearbymaxdist_flag=%d; ' .
				\		'gototag_item_arg=%s; ' .
				\		'gototag_curval_cmd=%s; ' .
				\		'gototag_curval_searchstring=%s; ' .
				\		'gototag_curval_searchstartpos=%s; ' .
				\		'gototag_curval_nearbymaxdist=%d;',
				\	log_pref, string(gototag_item),
				\	procflag,
				\	proc_usetagcmd_flag, proc_usesrchstr_flag,
				\	proc_usesearchstartpos_flag, proc_usenearbymaxdist_flag,
				\	(exists('gototag_item_arg') ? string(gototag_item_arg) : '<n/a>'),
				\	string(gototag_curval_cmd),
				\	string(gototag_curval_searchstring),
				\	(exists('gototag_curval_searchstartpos')
				\		? string(gototag_curval_searchstartpos) : '<n/a>'),
				\	gototag_curval_nearbymaxdist)

			" TODO: implement trying to jump to the tag (or using the command for
			" doing so ourselves) using the chosen method.
			if !procflag
				cal ctrlp#ev_log_printf(
					\	'%s verb execution has been skipped. ' .
					\		'gototag_item=%s; ' .
					\		'procflag=%d;',
					\	log_pref, string(gototag_item),
					\	procflag)

			elsei procflag && 0
				if gototag_item_type ==# 'itemtype_find_tag'
					if gototag_item_verb ==# 'findtag_tagcmd'
						if procflag
							" this will retrieve the best possible filename based on the
							" working directory (local or global).
							"-? let fname_intagfile = bufname(bufnr)
							let fname_intagfile = bufname(bufnr)
							let procflag = (!ctrlp#utils#fname_is_virtual(fname_intagfile))
								\	&& filereadable(fname_intagfile)
							if procflag
								let fname_intagfile = fnamemodify(fname_intagfile, ':p')
							en
						en

						" write a dummy tag file to a temporary file
						if procflag
							if empty(tmpfile_tags)
								let tmpfile_tags = ctrlp#tmpfm#get_tmpfilename_for(
									\	s:tmpfm_myid, 'tagutils_tags')
							en
							let procflag = !empty(tmpfile_tags)
						en

						if procflag
							" example:
							"  !_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
							"  !_TAG_FILE_SORTED	0	/0=unsorted, 1=sorted, 2=foldcase/
							"  !_TAG_PROGRAM_AUTHOR	Universal Ctags Team	//
							"  !_TAG_PROGRAM_NAME	Universal Ctags	/Derived from Exuberant Ctags/
							"  !_TAG_PROGRAM_URL	https://ctags.io/	/official site/
							"  !_TAG_PROGRAM_VERSION	0.0.0	/93228b8a/
							"  !_TAG_OUTPUT_MODE	u-ctags	/u-ctags or e-ctags/
							"  !_TAG_OUTPUT_FILESEP	slash	/slash or backslash/
							"  Basic Options	readme.md	/^## Basic Options$/;"	s	language:Markdown
							"  Basic Usage	readme.md	/^## Basic Usage$/;"	s	language:Markdown
							"  [...]
							let taglines_list = [
								\		[ '!_TAG_FILE_FORMAT', '2', '/extended format; --format=1 will not append ;" to lines/' ],
								\		[ '!_TAG_FILE_SORTED', '0', '/0=unsorted, 1=sorted, 2=foldcase/' ],
								\		[ '!_TAG_PROGRAM_NAME', 'ctrlp.vim', '/vim plugin/' ],
								\		[ '!_TAG_OUTPUT_FILESEP', 'slash', '/slash or backslash/' ],
								\		[ tagidentifier, fname_intagfile, gototag_curval_cmd ],
								\	]
							" make each inner list element a single tab-separated string.
							cal map(taglines_list, 'join(v:val, "\t")')
							let procflag = (writefile(taglines_list, tmpfile_tags) == 0)
							unl taglines_list
						en

						if procflag
							"? let cmd_tag_pref = ctrlp#utils#make_cmdstr_supported([
							"? 	\		'keepalt', 'noautocmd', 'keepjumps', 'hide'
							"? 	\	])
							let cmd_tag_pref = ''
							"-? let cmd_tag_now = cmd_tag_pref '1tag' escape(tagidentifier, ' "\')
							let cmd_tag_now = cmd_tag_pref . ' 1tag ' . escape(tagidentifier, ' "\')

							try
								let sav_l_tags = &l:tags
								if exists('+cscopetag')
									let sav_l_cscopetag = &cscopetag
									if &cscopetag | set nocscopetag | en
								en

								let &l:tags = ctrlp#utils#fnesc(tmpfile_tags, 'f')
								exe cmd_tag_now
								" make sure that we are in the destination file (buffer), just
								" in case.
								let procflag = (bufnr('%') == bufnr)
								let stateflag_found_tag = procflag

							" FIXME: MAYBE: add a 'catch' that just sets procflag = 0, and
							" remove the 'if !empty(v:exception) ... | en' freom the 'fina'
							" block.
							fina
								if !empty(v:exception) | let procflag = 0 | en
								try
									if !procflag
										" prev: let start_funcflags_now = start_funcflags . 'A'
										let start_funcflags_now = start_funcflags_restore
										if !ctrlp#tagutils#gobacktostartpos(
												\	start_curpos, start_bufnr, start_funcflags_now)
											let stateflag_proc_error = !0
											" MAYBE: conditionally set vars and 'break' from the loop.
											let proc_error_desc = printf(
												\		'failed to jump to the tag, and ' .
												\			'could not restore cursor position ' .
												\			'to the ''start''. ' .
												\			'bufnr=%d; curpos=%s; start_funcflags=%s;',
												\		start_bufnr, string(start_curpos),
												\		string(start_funcflags_now))
											brea
										en
									en
									" prev: "-? if bufnr('%') == start_bufnr
									" prev: "-? 	if exists('sav_l_tags') && (&l:tags != sav_l_tags)
									" prev: "-? 		let &l:tags = sav_l_tags
									" prev: "-? 	en
									" prev: "-? en
									" prev: let opts_to_restore = filter(
									" prev: 	\	[
									" prev: 	\		['l:tags', 'sav_l_tags'],
									" prev: 	\	], 'exists(v:val[1])')
									" prev: if !empty(opts_to_restore)
									" prev: 	" TODO: implement this function: ctrlp#utils#restore_vals_in_buf()
									" prev: 	"  ref: fu! ctrlp#utils#execute_in_buffer(bufexp, cmd) abort
									" prev: 	cal ctrlp#utils#restore_vals_in_buf(
									" prev: 		\	start_bufnr, opts_to_restore)
									" prev: en
									" TODO: implement this function: ctrlp#utils#restore_vals_in_buf()
									"  ref: fu! ctrlp#utils#execute_in_buffer(bufexp, cmd) abort
									cal ctrlp#utils#restore_vals_in_buf(
										\	start_bufnr, map(
										\	filter(
										\		[
										\			['&l:tags', 'sav_l_tags'],
										\		], 'exists(v:val[1])'),
										\	'[ v:val[0], eval(v:val[1]) ]'))
									" as (AFAICT) no function to restore global options exists,
									" we restore this one manually.
									if exists('sav_l_cscopetag')
											\	&& (&cscopetag != sav_l_cscopetag)
										let &cscopetag = sav_l_cscopetag
									en

								fina
									unl! sav_l_tags
								endt
							endt
						en

					elsei gototag_item_verb ==# 'findtag_execmd'
						" done: beware of the search register, too. see ':h let-@',
						"  ':h let-register', ':h quote/'
						"  done: put this in a function? or just save-and-restore the
						"  register inside this function?
						" TODO: switch (with 'keepjumps') to the tag's buffer
						"  ref: s:accepttag_movetobufcur_nojumps_cmd_pref
						let cmd_proc_list = []
						if (bufnr('%') != bufnr)
							cal add(
								\	cmd_proc_list,
								\	['b ' . bufnr, 'bufnr(''%'') == bufnr' ])
						en
						" TODO: add other entries (to jump to the "current" cmd)

						let procflag = procflag && (!empty(cmd_proc_list))
						if procflag
							for cmd_proc_entry in cmd_proc_list
								let cmd_proc_cmd = cmd_proc_entry[0]
								let cmd_proc_postcond = get(cmd_proc_entry, 1, '')

								try
									" TODO: execute command (optionally not using 'keepjumps' on
									" the first command)
									" we instruct to optionally insert an entry in the 'jumplist'
									" (if that's available, although vim won't do that, as we're
									" currently at the "startpos" already) and move forward in the
									" 'jumplist'.

									if !empty(cmd_proc_postcond)
										let procflag = procflag && eval(cmd_proc_postcond)
									en

								cat
									" for now, do not report exceptions cause by the "find tag"
									" command(s).
									let procflag = 0

								fina
									" TODO: go back to the "startpos"
									"  IDEA: refactor the code for both cases into:
									"
									"   * 'fina' block -> move to a single 'if !procflag' (taken
									"			from the existing 'fina' block in the 'findtag_tagcmd'
									"			branch) outside this 'if procflag', so:
									"
									"			* TODO: add a "proc"-style variable to indicate that
									"				we need to go back to the startpos -- or:
									"				IDEA: just use the
									"				'proc_gotostart_flag && !procflag' condition to
									"				determine that we should restore the "startpos"
									"				adding the 'A' flag to the appropriate
									"				ctrlp#tagutils#gobacktostartpos() parameter.
									"
									"			* in this context, variables like sav_l_tags and
									"				others can be assumed to need restoring in the same
									"				'if !procflag', if they exist (which they should not
									"				unless there has been an attempt in the current
									"				outer loop iteration to override its value in the
									"				"startpos" buffer).
									"
									"				* TODO: for simplicity/maintainability, make sure we
									"					add these 'sav_l_*' variables to an 'unlet!'
									"					command near the beginning of the loop's body.
								endt
							endfo
						en
						" TODO: set up variable(s) with the command to go to the tag's
						" definition (from this function's parameter(s))
						" TODO: probably use the same 'if' (mentioned in the 'if' above) to
						" conditionally update stateflag_found_tag
						" NOTE: MAYBE: also use 'keepjumps' as a prefix for the executed
						" command.
						" ref: if tgaddr =~# '\v^[/\?]'
						" ref:	exe 'keepjumps ' . ( ( tgaddr[0] ==# '/' ) ? '1' : '$' )
						" FIXME: remove -- added so that we notice this hasn't worked.
						let procflag = 0

					en

				elsei gototag_item_type ==# 'itemtype_tagfound_post'
					try
						let sav_l_bufnr = bufnr('%')
						let sav_l_wincurstate = ctrlp#utils#getwincursorstate()

						if gototag_item_verb ==# 'post_execmd'
							" NOTE: allow exceptions to propagate and be handled in this
							" function, if necessary.
							sandbox exe gototag_curval_cmd

						elsei gototag_item_verb ==# 'post_search_nearby'
							" TODO: handle patterns *and* strings
							"  NOTE: for now, the "search string" is actually a pattern.
							"  IDEA: #1: rename 'set_searchstring' to 'set_searchpattern'
							let procflag = procflag &&
								\	s:search_nearby_move(
								\		gototag_curval_searchstring, gototag_curval_nearbymaxdist)
							if procflag | let stateflag_post_searchnearby_done = !0 | en
						en

					fina
						if !empty(v:exception) | let procflag = 0 | en
						try
							if !procflag
								if exists('sav_l_bufnr') && (bufnr('%') != sav_l_bufnr)
									exe s:accepttag_movetobufcur_nojumps_cmd_pref .
										\	' b ' . sav_l_bufnr
								en
								if exists('sav_l_wincurstate')
									cal ctrlp#utils#setwincursorstate(sav_l_wincurstate)
								en
							en

						fina
							unl! sav_l_bufnr sav_l_wincurstate
						endt
					endt

				en

				if !procflag
					cal ctrlp#ev_log_printf(
						\	'%s verb was either not executed or its execution failed. ' .
						\		'gototag_item=%s; ' .
						\		'procflag=%d;',
						\	log_pref, string(gototag_item),
						\	procflag)
				en

			elsei procflag && 1 &&
				\	(	index(
				\			['itemtype_find_tag', 'itemtype_tagfound_post'],
				\			gototag_item_type)
				\		>= 0
				\	)
				unl! trycatch_outer_exception trycatch_outer_throwpoint
				try
					cal ctrlp#ev_log_printf(
						\	'%s about to process verb with ''undo position'' support. ' .
						\		'gototag_item_verb=%s;',
						\	log_pref,
						\	string(gototag_item_verb))

					" save current state
					if gototag_item_type ==# 'itemtype_tagfound_post'
						let sav_l_bufnr = bufnr('%')
						let sav_l_wincurstate = ctrlp#utils#getwincursorstate()
					en

					" execute the action associated to the current verb
					if gototag_item_type ==# 'itemtype_find_tag'
						if gototag_item_verb ==# 'findtag_tagcmd'
							if procflag
								" this will retrieve the best possible filename based on the
								" working directory (local or global).
								let fname_intagfile = bufname(bufnr)
								let procflag = (!ctrlp#utils#fname_is_virtual(fname_intagfile))
									\	&& filereadable(fname_intagfile)
								if procflag
									let fname_intagfile = fnamemodify(fname_intagfile, ':p')
								en
							en

							" write a dummy tag file to a temporary file
							if procflag
								if empty(tmpfile_tags)
									let tmpfile_tags = ctrlp#tmpfm#get_tmpfilename_for(
										\	s:tmpfm_myid, 'tagutils_tags')
								en
								let procflag = !empty(tmpfile_tags)
							en

							if procflag
								" example:
								"  !_TAG_FILE_FORMAT	2	/extended format; --format=1 will not append ;" to lines/
								"  !_TAG_FILE_SORTED	0	/0=unsorted, 1=sorted, 2=foldcase/
								"  !_TAG_PROGRAM_AUTHOR	Universal Ctags Team	//
								"  !_TAG_PROGRAM_NAME	Universal Ctags	/Derived from Exuberant Ctags/
								"  !_TAG_PROGRAM_URL	https://ctags.io/	/official site/
								"  !_TAG_PROGRAM_VERSION	0.0.0	/93228b8a/
								"  !_TAG_OUTPUT_MODE	u-ctags	/u-ctags or e-ctags/
								"  !_TAG_OUTPUT_FILESEP	slash	/slash or backslash/
								"  Basic Options	readme.md	/^## Basic Options$/;"	s	language:Markdown
								"  Basic Usage	readme.md	/^## Basic Usage$/;"	s	language:Markdown
								"  [...]
								let taglines_list = [
									\		[ '!_TAG_FILE_FORMAT', '2', '/extended format; --format=1 will not append ;" to lines/' ],
									\		[ '!_TAG_FILE_SORTED', '0', '/0=unsorted, 1=sorted, 2=foldcase/' ],
									\		[ '!_TAG_PROGRAM_NAME', 'ctrlp.vim', '/vim plugin/' ],
									\		[ '!_TAG_OUTPUT_FILESEP', 'slash', '/slash or backslash/' ],
									\		[ tagidentifier, fname_intagfile, gototag_curval_cmd ],
									\	]
								" make each inner list element a single tab-separated string.
								cal map(taglines_list, 'join(v:val, "\t")')
								let procflag = (writefile(taglines_list, tmpfile_tags) == 0)
								unl taglines_list
							en

							if procflag
								"? let cmd_tag_pref = ctrlp#utils#make_cmdstr_supported([
								"? 	\		'keepalt', 'noautocmd', 'keepjumps', 'hide'
								"? 	\	])
								let cmd_tag_pref = ''
								"-? let cmd_tag_now = cmd_tag_pref '1tag' escape(tagidentifier, ' "\')
								let cmd_tag_now = cmd_tag_pref . ' 1tag ' . escape(tagidentifier, ' "\')

								" more "state saving" just before executing the command
								let sav_l_tags = &l:tags
								if exists('+cscopetag')
									let sav_l_cscopetag = &cscopetag
									if &cscopetag | set nocscopetag | en
								en

								let &l:tags = ctrlp#utils#fnesc(tmpfile_tags, 'f')
								" execute the command now (which can throw, and that will be
								" handled in this scope's 'catch' and/or 'finally' blocks.
								exe cmd_tag_now
								" make sure that we are in the destination file (buffer), just
								" in case.
								let procflag = (bufnr('%') == bufnr)
								let stateflag_found_tag = procflag
							en

						" prev: elsei gototag_item_verb ==# 'findtag_execmd'
						elsei index(
								\	['findtag_execmd', 'findtag_searchnearby'],
								\	gototag_item_verb) >= 0
							let cmd_proc_list = []
							if (bufnr('%') != bufnr)
								cal add(
									\	cmd_proc_list,
									\	['b ' . bufnr, 'bufnr(''%'') == bufnr' ])
							el
								" as we're in the right buffer, we'll execute a command to add
								" a jumplist entry at the current position, and then we'll
								" jump to the cursor position we were at before the command
								" that created that jumplist entry.
								let cmd_l_start_curpos = ctrlp#utils#getcurpos()
								cal extend(
									\	cmd_proc_list,
									\	[
									\		['normal! H'],
									\		['cal setpos(''.'', cmd_l_start_curpos)'],
									\	])
							en

							" go to the appropriate starting position for the main
							" command/operation associated to gototag_item_verb.
							if proc_usesearchstartpos_flag
									\	&& gototag_curval_searchstartpos[1] > 0
								cal add(
									\	cmd_proc_list,
									\	['cal setpos(''.'', gototag_curval_searchstartpos)'])
							elsei gototag_item_verb ==# 'findtag_execmd'
								" add command to position the cursor at the best possible
								" position from which to execute the command -- if we can work
								" that positioning command at all.
								if gototag_curval_cmd =~# '\v^[/\?]'
									cal add(
										\	cmd_proc_list,
										\	[	( ( gototag_curval_cmd[0] ==# '/' )
										\			? '1' : '$ | normal! $'
										\		)
										\	])
								en
							en

							if gototag_item_verb ==# 'findtag_searchnearby'
								cal add(
									\	cmd_proc_list,
									\	[	'let procflag = procflag && ' .
									\			's:search_nearby_move( ' .
									\			'	gototag_curval_searchstring, ' .
									\			'	gototag_curval_nearbymaxdist)' ])
							elsei gototag_item_verb ==# 'findtag_execmd'
								" prev: cal add(cmd_proc_list, [gototag_curval_cmd])
								"? cal add(cmd_proc_list, ['sandbox ' . gototag_curval_cmd])
								cal add(cmd_proc_list, [gototag_curval_cmd, '', 1])
							" MAYBE: el ... throw error 'unsupported command verb'
							en

							let procflag = procflag && (!empty(cmd_proc_list))
							if procflag
								cal ctrlp#ev_log_printf(
									\	'%s about to run commands ' .
									\		'associated to the current verb. ' .
									\		'gototag_item_verb=%s; gototag_curval_cmd=%s; ' .
									\		'cmd_proc_list=%s;',
									\	log_pref,
									\	string(gototag_item_verb), string(gototag_curval_cmd),
									\	string(cmd_proc_list))
								let proc_addedjumplistentry = 0
								let cmd_pref_keepjumps =
									\	empty(s:accepttag_movetobufcur_nojumps_cmd_pref)
									\	? ''
									\	: s:accepttag_movetobufcur_nojumps_cmd_pref . ' '
								for cmd_proc_entry in cmd_proc_list
									let cmd_proc_cmd = cmd_proc_entry[0]
									let cmd_proc_postcond = get(cmd_proc_entry, 1, '')
									let cmd_proc_execsafely_flag = get(cmd_proc_entry, 2, 0)

									if proc_addedjumplistentry
										" following commands need to leave the jumplist alone.
										let cmd_proc_cmd = cmd_pref_keepjumps . cmd_proc_cmd
									el
										" our first command needs to add a jumplist entry.
										" add the command prefix on the next iteration (if there
										" is one).
										let proc_addedjumplistentry = !0
									en

									cal ctrlp#ev_log_printf(
										\	'%s about to run command. ' .
										\		'cmd=%s; postcond=%s; ' .
										\		'execsafely_flag=%d;',
										\	log_pref,
										\	string(cmd_proc_cmd), string(cmd_proc_postcond),
										\	cmd_proc_execsafely_flag)
									" this can throw, but we're handling that in this scope's
									" enclosing 'try..catch..finally..endtry' block.
									" NOTE: this 'execute' command might also update local
									" variables (such as 'procflag'), so don't assume much after
									" this line has successfully executed.
									if cmd_proc_execsafely_flag
										sandbox exe cmd_proc_cmd
									el
										exe cmd_proc_cmd
									en

									if !empty(cmd_proc_postcond)
										let procflag = procflag && eval(cmd_proc_postcond)
									en
								endfo
							en
							unl! cmd_l_start_curpos
							let stateflag_found_tag = procflag

						en

					elsei gototag_item_type ==# 'itemtype_tagfound_post'
						if gototag_item_verb ==# 'post_execmd'
							" NOTE: allow exceptions to propagate and be handled in this
							" function, if necessary.
							sandbox exe gototag_curval_cmd

						elsei gototag_item_verb ==# 'post_search_nearby'
							" TODO: handle patterns *and* strings
							"  NOTE: for now, the "search string" is actually a pattern.
							"  IDEA: #1: rename 'set_searchstring' to 'set_searchpattern'
							let procflag = procflag &&
								\	s:search_nearby_move(
								\		gototag_curval_searchstring, gototag_curval_nearbymaxdist)
							if procflag | let stateflag_post_searchnearby_done = !0 | en
						en
					en

				cat
					let procflag = 0
					let [trycatch_outer_exception, trycatch_outer_throwpoint] =
						\	[v:exception, v:throwpoint]
					" do not propagate the exception (there are more cleanups to
					" be done below).

				fina
					"? if !empty(v:exception) | let procflag = 0 | en
					if !procflag
						cal ctrlp#ev_log_printf(
							\	'%s failed executing the command(s) associated to ' .
							\		'the chosen item verb. ' .
							\		'v:exception=%s; v:throwpoint=%s; ' .
							\		'gototag_item_verb=%s;',
							\	log_pref,
							\	(	exists('trycatch_outer_exception')
							\		? string(trycatch_outer_exception) : '<n/a>'),
							\	(	exists('trycatch_outer_throwpoint')
							\		?	string(trycatch_outer_throwpoint) : '<n/a>'),
							\	string(gototag_item_verb))
					en
					unl! trycatch_outer_exception trycatch_outer_throwpoint

					unl! restoreflag_success
					let restoreflag_finally_break_flag = 0

					if !procflag
						try
							if exists('sav_l_bufnr') && (bufnr('%') != sav_l_bufnr)
								exe s:accepttag_movetobufcur_nojumps_cmd_pref .
									\	' b ' . sav_l_bufnr
							en
							if exists('sav_l_wincurstate')
								cal ctrlp#utils#setwincursorstate(sav_l_wincurstate)
							en

						cat
							let restoreflag_finally_break_flag = !0
							if (!stateflag_proc_error)
								let stateflag_proc_error = !0
								" MAYBE: conditionally set vars and 'break' from the loop.
								let proc_error_desc = printf(
									\		'failed to restore previous bufnr/cursor position. ' .
									\			'v:exception=%s; v:throwpoint=%s; ' .
									\			'bufnr=%s; wincurstate=%s;',
									\		string(v:exception), string(v:throwpoint),
									\		(exists('sav_l_bufnr') ? string(sav_l_bufnr) : '<n/a>'),
									\		(exists('sav_l_wincurstate')
									\			?	string(sav_l_wincurstate) : '<n/a>'))
							en
							" do not propagate the exception (there are more cleanups to
							" be done below).

						" prev: fina
						" prev: 	unl! sav_l_bufnr sav_l_wincurstate
						endt
					en
					unl! sav_l_bufnr sav_l_wincurstate

					if (!procflag) && proc_gotostart_flag
						let restoreflag_success = !0
						unl! trycatch_inner_exception trycatch_inner_throwpoint
						try
							" prev: let start_funcflags_now = start_funcflags . 'A'
							let start_funcflags_now = start_funcflags_restore
							let restoreflag_success = restoreflag_success &&
									\	ctrlp#tagutils#gobacktostartpos(
									\		start_curpos, start_bufnr, start_funcflags_now)

						cat
							let restoreflag_success = 0
							let [trycatch_inner_exception, trycatch_inner_throwpoint] =
								\	[v:exception, v:throwpoint]
							" do not propagate the exception (there are more cleanups to
							" be done below).

						fina
							"? if !empty(v:exception) | let restoreflag_success = 0 | en
							if !restoreflag_success
								let restoreflag_finally_break_flag = !0
								if (!stateflag_proc_error)
									let stateflag_proc_error = !0
									" MAYBE: conditionally set vars and 'break' from the loop.
									let proc_error_desc = printf(
										\		'failed to perform the operation, and ' .
										\			'could not restore cursor ' .
										\			'to the ''start''ing bufnr+position. ' .
										\			'v:exception=%s; v:throwpoint=%s; ' .
										\			'bufnr=%d; curpos=%s; start_funcflags=%s;',
										\		(	exists('trycatch_inner_exception')
										\			? string(trycatch_inner_exception) : '<n/a>'),
										\		(	exists('trycatch_inner_throwpoint')
										\			?	string(trycatch_inner_throwpoint) : '<n/a>'),
										\		start_bufnr, string(start_curpos),
										\		string(start_funcflags_now))
								en
							en
							"+? unl! trycatch_inner_exception trycatch_inner_throwpoint
							unl! restoreflag_success

						endt
					en

					try
						cal ctrlp#utils#restore_vals_in_buf(
							\	start_bufnr, map(
							\	filter(
							\		[
							\			['&l:tags', 'sav_l_tags'],
							\		], 'exists(v:val[1])'),
							\	'[ v:val[0], eval(v:val[1]) ]'))
						" as (AFAICT) no function to restore global options exists,
						" we restore this one manually.
						if exists('sav_l_cscopetag')
								\	&& (&cscopetag != sav_l_cscopetag)
							let &cscopetag = sav_l_cscopetag
						en

					cat
						let restoreflag_finally_break_flag = !0
						if (!stateflag_proc_error)
							let stateflag_proc_error = !0
							" MAYBE: conditionally set vars and 'break' from the loop.
							let proc_error_desc = printf(
								\		'failed to recover buffer-local and global options. ' .
								\			'v:exception=%s; v:throwpoint=%s; ',
								\		string(v:exception), string(v:throwpoint))
						en
						" do not propagate the exception (there are more cleanups to be
						" done below).

					fina
						unl! bufnr_now
							\	sav_l_tags sav_l_cscopetag
							\	taglines_list

					endt

					" act on the control flag(s) value(s) after attempting to restore as
					" many settings and state as possible.
					if restoreflag_finally_break_flag | brea | en
				endt

			en

			" MAYBE: we don't really need postop_curpos, as we need to assume that
			" the position for each "post" operation will be restored to *its*
			" starting point if that particular one fails.
			"? if procflag
			"? 	" save the position to execute the "post" commands/operations from
			"? 	if (gototag_item_type ==# 'itemtype_find_tag')
			"? 		\	&& stateflag_found_tag
			"? 		\	&& (!exists('postop_curpos'))
			"? 	en
			"? en
		endfo

	fina
		let [sav_exception, sav_throwpoint] = [v:exception, v:throwpoint]
		let exception_count = empty(sav_exception) ? 0 : 1
		" prev: if exists('sav_magic') && (&magic != sav_magic)
		" prev: 	let &magic = sav_magic
		" prev: en
		" prev: try
		" prev: 	ctrlp#tmpfm#cleanup_for(s:tmpfm_myid)
		" prev: cat
		" prev: 	if empty(sav_exception)
		" prev: 		let [sav_exception, sav_throwpoint] = [v:exception, v:throwpoint]
		" prev: 	en
		" prev: endt
		" prev: if !empty(sav_exception) && (sav_exception != v:exception)
		" prev: 	th printf(
		" prev: 		\	'%s re-throwing. exception=%s; throwpoint=%s;',
		" prev: 		\	except_pref, string(sav_exception), string(sav_throwpoint))
		" prev: en
		" prev: for t_stageid in ['trystageid_magic', 'trystageid_tmpfiles']
		" prev: 	try
		" prev: 		if t_stageid ==# 'trystageid_magic'
		" prev: 			if exists('sav_magic') && (&magic != sav_magic)
		" prev: 				let &magic = sav_magic
		" prev: 			en
		" prev: 		elsei t_stageid ==# 'trystageid_tmpfiles'
		" prev: 			cal ctrlp#tmpfm#cleanup_for(s:tmpfm_myid)
		" prev: 		en
		" prev: 	cat
		" prev: 		let exception_count += 1
		" prev: 		if empty(sav_exception)
		" prev: 			let [sav_exception, sav_throwpoint] = [v:exception, v:throwpoint]
		" prev: 		en
		" prev: 	endt
		" prev: endfo
		for t_stageid in ['trystageid_savedvalues', 'trystageid_tmpfiles']
			try
				if t_stageid ==# 'trystageid_savedvalues'
					" ref: if exists('sav_magic') && (&magic != sav_magic)
					for [t_sav_varname, t_sav_expr; t_sav_rest_list]
							\	in saved_exprs_search_list
						try
							if !(exists(t_sav_varname) &&
									\	(eval(t_sav_expr) !=# {t_sav_varname}))
								con
							en
							" NOTE: this does not work for '@/'
							"- let {t_sav_expr} = {t_sav_varname}
							exe printf('let %s = %s', t_sav_expr, '{t_sav_varname}')
						cat
							" MAYBE: report/log error
						endt
					endfo
					unl! t_sav_varname t_sav_expr t_sav_rest_list
				elsei t_stageid ==# 'trystageid_tmpfiles'
					cal ctrlp#tmpfm#cleanup_for(s:tmpfm_myid)
				en
			cat
				let exception_count += 1
				if empty(sav_exception)
					let [sav_exception, sav_throwpoint] = [v:exception, v:throwpoint]
				en
			endt
		endfo

		" ref: let pos_on_notfound = get(a:kwargs, 'pos_on_notfound', 'go_back')
		" ref: let action_on_notfound = get(a:kwargs, 'action_on_notfound', 'return_code')
		if (!stateflag_found_tag)
			let stateflag_posonnotfound_done = 0

			" prev: if (!stateflag_posonnotfound_done) && pos_on_notfound ==# 'go_back'
			" prev: 	try
			" prev: 		if exists('restorepos_start_bufnr')
			" prev: 				\	&& exists('restorepos_start_curpos')
			" prev: 			" TODO: try to go back

			" prev: 			let stateflag_posonnotfound_done = !0
			" prev: 		en

			" prev: 	fina
			" prev: 		if !stateflag_posonnotfound_done
			" prev: 			let pos_on_notfound = 'stay_target_file'
			" prev: 		en
			" prev: 	endt
			" prev: en

			" prev: if (!stateflag_posonnotfound_done) && pos_on_notfound ==# 'stay_target_file'
			" prev: 	" MAYBE: implement also restorepos_tgt_bufnr, restorepos_tgt_curpos
			" prev: 	" TODO: implement
			" prev: en

			" prev: if (!stateflag_posonnotfound_done) && pos_on_notfound ==# 'stay_best_effort'
			" prev: 	" TODO: implement
			" prev: en

			" prev: if (!stateflag_posonnotfound_done)
			" prev: 		\	&& (!(stateflag_proc_error || exists('except_reason')))
			" prev: 	" TODO: (optionally?) report error
			" prev: en

			" prev: let proc_posonnotfound_list = [
			" prev: 			\		[
			" prev: 			\			'go_back',
			" prev: 			\			'restorepos_start_bufnr', 'restorepos_start_curpos',
			" prev: 			\		],
			" prev: 			\		[
			" prev: 			\			'stay_target_file',
			" prev: 			\			'restorepos_tgt_bufnr', 'restorepos_tgt_curpos',
			" prev: 			\		],
			" prev: 			\		[
			" prev: 			\			'stay_best_effort',
			" prev: 			\			'FIXME_TODO_restorepos__bufnr', 'FIXME_TODO_restorepos__curpos',
			" prev: 			\		],
			" prev: 			\	]

			" prev: " leave only the entries that make sense for us to try
			" prev: cal filter(
			" prev: 	\	proc_posonnotfound_list,
			" prev: 	\	'exists(v:val[1]) && exists(v:val[2]) && ' .
			" prev: 	\		'(type(eval(v:val[1])) == s:typeid_num) && ' .
			" prev: 	\		'(type(eval(v:val[2])) == s:typeid_list)')

			" prev: " FIXME: implement sensible "fallbacks" for each possible value for
			" prev: " 'pos_on_notfound'.
			" prev: let posonnotfound_iter_contflag = !0
			" prev: " prev: " prev: for posonnotfound_iter_main_now in range(2)
			" prev: " prev: for posonnotfound_iter_main_now in range(1)
			" prev: " prev: 	" prev: if stateflag_posonnotfound_done | brea | en
			" prev: " prev: 	if !posonnotfound_iter_contflag | brea | en
			" prev: " prev: 	" prev: for [posonnotfound_id_now,
			" prev: " prev: 	" prev: 		\	posonnotfound_varname_bufnr_now,
			" prev: " prev: 	" prev: 		\	posonnotfound_varname_curpos_now,
			" prev: " prev: 	" prev: 		\	posonnotfound_id_fback_nextup, posonnotfound_id_fback_onerror]
			" prev: " prev: 	" prev: 		\	in [
			" prev: " prev: 	" prev: 		\		[
			" prev: " prev: 	" prev: 		\			'go_back',
			" prev: " prev: 	" prev: 		\			'restorepos_start_bufnr', 'restorepos_start_curpos',
			" prev: " prev: 	" prev: 		\			'', 'stay_target_file',
			" prev: " prev: 	" prev: 		\		],
			" prev: " prev: 	" prev: 		\		[
			" prev: " prev: 	" prev: 		\			'stay_target_file',
			" prev: " prev: 	" prev: 		\			'restorepos_start_bufnr', 'restorepos_start_curpos',
			" prev: " prev: 	" prev: 		\			'go_back', 'stay_best_effort',
			" prev: " prev: 	" prev: 		\		],
			" prev: " prev: 	" prev: 		\		[
			" prev: " prev: 	" prev: 		\			'stay_best_effort',
			" prev: " prev: 	" prev: 		\			'restorepos_start_bufnr', 'restorepos_start_curpos',
			" prev: " prev: 	" prev: 		\			'stay_target_file', '',
			" prev: " prev: 	" prev: 		\		],
			" prev: " prev: 	" prev: 		\	]
			" prev: " prev: 	if posonnotfound_iter_main_now > 0
			" prev: " prev: 		" reverses lists in-place.
			" prev: " prev: 		cal reverse(proc_posonnotfound_list)
			" prev: " prev: 	en
			" prev: " prev: 	"? let posonnotfound_id_prev = ''
			" prev: " prev: 	for [posonnotfound_id_now,
			" prev: " prev: 			\	posonnotfound_varname_bufnr_now, posonnotfound_varname_curpos_now]
			" prev: " prev: 			\	in proc_posonnotfound_list
			" prev: " prev: 		" prev: if stateflag_posonnotfound_done | brea | en
			" prev: " prev: 		if !posonnotfound_iter_contflag | brea | en

			" prev: " prev: 		" TODO: implement body (try..catch..endtry, signalling to exit all
			" prev: " prev: 		" the loops on unrecoverable errors, etc.)
			" prev: " prev: 		" TODO: update stateflag_posonnotfound_done (true) *and*
			" prev: " prev: 		" posonnotfound_iter_contflag (to false) when we have succeeded.

			" prev: " prev: 		"? let posonnotfound_id_prev = posonnotfound_id_now
			" prev: " prev: 	endfo
			" prev: " prev: endfo

			let proc_posonnotfound_dict = {
				\		'go_back': {
				\			'pos_varnames_list': [
				\					'restorepos_start_bufnr', 'restorepos_start_curpos',
				\				],
				\			},
				\		'stay_target_file': {
				\			'pos_varnames_list': [
				\					'restorepos_tgt_bufnr', 'restorepos_tgt_curpos',
				\				],
				\			},
				\		'stay_best_effort': {
				\			'pos_varnames_list': [
				\					'FIXME_TODO_restorepos__bufnr', 'FIXME_TODO_restorepos__curpos',
				\				],
				\			},
				\	}
			let proc_posonnotfound_idorder_list = [
				\	'go_back', 'stay_target_file', 'stay_best_effort', ]

			let pos_varvalues_types = [s:typeid_num, s:typeid_list]
			" prev: " leave only the entries that make sense for us to try
			" prev: "? cal filter(
			" prev: "? 	\	proc_posonnotfound_dict,
			" prev: "? 	\	'empty(filter( ' .
			" prev: "? 	\			'copy(v:val[''pos_varnames_list'']), ' .
			" prev: "? 	\			'"!exists(v:val)")) && ' .
			" prev: "? 	\		'map(copy(v:val[''pos_varnames_list'']), ' .
			" prev: "? 	\			'"type(eval(v:val))") == pos_varvalues_types ')
			" prev: cal filter(
			" prev: 	\	proc_posonnotfound_dict,
			" prev: 	\	'map(copy(v:val[''pos_varnames_list'']), ' .
			" prev: 	\		'"exists(v:val) ? type(eval(v:val)) : -1") == pos_varvalues_types ')
			cal map(
				\	proc_posonnotfound_dict,
				\	'extend(v:val, {"pos_vars_valid": ' .
				\		'map(copy(v:val[''pos_varnames_list'']), ' .
				\			'"exists(v:val) ? type(eval(v:val)) : -1") == ' .
				\				'pos_varvalues_types ' .
				\		'})')
			unl pos_varvalues_types
			cal ctrlp#ev_log_printf(
				\	'%s tag not found. about to attempt to restore the requested ' .
				\		'bufnr+position. ' .
				\		'pos_on_notfound=%s; proc_posonnotfound_dict=%s;',
				\	log_pref,
				\	string(pos_on_notfound), string(proc_posonnotfound_dict))

			for [posonnotfound_iter_abortonerr, posonnotfound_iter_ids_list] in
					\	[
					\		[1, proc_posonnotfound_idorder_list],
					\		[0, reverse(copy(proc_posonnotfound_idorder_list))],
					\	]
				" prev: if !posonnotfound_iter_contflag | brea | en
				if stateflag_posonnotfound_done | brea | en

				" process dictionary elements in the order defined by
				" 'proc_posonnotfound_idorder_list', starting at the one that matches
				" 'pos_on_notfound' until the end of the list.
				let posonnotfound_iter_foundreqid = 0
				for posonnotfound_id_now in posonnotfound_iter_ids_list
					" prev: if !posonnotfound_iter_contflag | brea | en

					" conditionally update this flag to know whether we need to skip
					" this id.
					let posonnotfound_iter_foundreqid =
						\	posonnotfound_iter_foundreqid ||
						\	(posonnotfound_id_now ==# pos_on_notfound)
					" skip this entry if we're not meant to process it just yet.
					if !posonnotfound_iter_foundreqid | con | en

					let posonnotfound_procdictentry_now =
						\	proc_posonnotfound_dict[posonnotfound_id_now]
					" prev: if !(posonnotfound_iter_foundreqid &&
					" prev: 		\	posonnotfound_procdictentry_now['pos_vars_valid'])
					" prev: 	con
					" prev: en
					" skip this entry if we can't (missing variables, etc.).
					if !posonnotfound_procdictentry_now['pos_vars_valid'] | con | en
					" skip this entry if it has already been processed (tried).
					if get(posonnotfound_procdictentry_now, 'processed') | con | en

					" attempt to restore the position, handle exceptions, etc.
					let restoreflag_success = !0
					unl! restorepos_now_bufnr restorepos_now_curpos
					try
						" prev: \	eval(posonnotfound_procdictentry_now['pos_varnames_list'])
						let [restorepos_now_bufnr, restorepos_now_curpos] =
							\	map(
							\		copy(posonnotfound_procdictentry_now['pos_varnames_list']),
							\		'eval(v:val)')
						let restorepos_now_funcflags = start_funcflags_restore
						" mark this attempt as "done", so even in the case of an error, we
						" don't try this particular one again.
						let posonnotfound_procdictentry_now['processed'] = 1
						cal ctrlp#ev_log_printf(
							\	'%s about to try to restore bufnr+position. ' .
							\		'posonnotfound_id_now=%s; ' .
							\		'restorepos_now_bufnr=%d; ' .
							\		'restorepos_now_curpos=%s; ' .
							\		'restorepos_now_funcflags=%s;',
							\	log_pref,
							\	string(posonnotfound_id_now),
							\	restorepos_now_bufnr,
							\	string(restorepos_now_curpos),
							\	string(restorepos_now_funcflags))
						let restoreflag_success = restoreflag_success &&
								\	ctrlp#tagutils#gobacktostartpos(
								\		restorepos_now_curpos, restorepos_now_bufnr,
								\		restorepos_now_funcflags)

					cat
						let restoreflag_success = 0
						"-? let exception_count += 1
						"-? if empty(sav_exception)
						"-? 	let [sav_exception, sav_throwpoint] = [v:exception, v:throwpoint]
						"-? en
						cal ctrlp#ev_log_printf(
							\	'%s caught exception whilst trying to go back to ' .
							\		'a restore position. ' .
							\		'v:exception=%s; v:throwpoint=%s;',
							\	log_pref, string(v:exception), string(v:throwpoint))

					endt
					cal ctrlp#ev_log_printf(
						\	'%s restore bufnr+position attempt completed. ' .
						\		'posonnotfound_id_now=%s; ' .
						\		'success=%d; bufnr()=%d; curpos=%s; ' .
						\		'abortonerror_flag=%d;',
						\	log_pref,
						\	string(posonnotfound_id_now),
						\	restoreflag_success, bufnr('%'), string(ctrlp#utils#getcurpos()),
						\	posonnotfound_iter_abortonerr)
					if restoreflag_success
						let stateflag_posonnotfound_done = !0
						" prev: let posonnotfound_iter_contflag = 0
						brea
					elsei posonnotfound_iter_abortonerr
						" prev: "-? let posonnotfound_iter_contflag = 0
						brea
					en
				endfo
			endfo

			cal ctrlp#ev_log_printf(
				\	'%s %s bufnr+position. ' .
				\		'pos_on_notfound=%s; ' .
				\		'bufnr()=%d; curpos=%s;',
				\	log_pref,
				\	(	stateflag_posonnotfound_done
				\		?	'successfully restored'
				\		:	'failed to restore'
				\	),
				\	string(pos_on_notfound),
				\	bufnr('%'), string(ctrlp#utils#getcurpos()))
			unl stateflag_posonnotfound_done
		en

		if !empty(sav_exception) && (sav_exception != v:exception)
			th printf(
				\	'%s re-throwing. exception_count=%d; ' .
				\		'first caught: exception=%s; throwpoint=%s;',
				\	except_pref, exception_count,
				\	string(sav_exception), string(sav_throwpoint))
		en

		if !exists('proc_onnotfound_actiontaken_desc')
			let proc_onnotfound_actiontaken_desc = ''
		en

		if stateflag_proc_error
			if !exists('proc_error_desc') || empty(proc_error_desc)
				let proc_error_desc = 'unknown/general error'
			en
			" prev: if exists('proc_onnotfound_actiontaken_desc') &&
			" prev: 		\	(!empty(proc_onnotfound_actiontaken_desc))
			if !empty(proc_onnotfound_actiontaken_desc)
				let proc_error_desc .=
					\	(empty(proc_error_desc) ? '' : '; ') .
					\	'action: ' . proc_onnotfound_actiontaken_desc
			en
			" TODO: decide whether to log, throw an exception, or return a value?
			" NOTE: for now, we'll throw
			if !exists('except_reason') || empty(except_reason)
				let except_reason = proc_error_desc
			en
		"? el
		"? 	unl! proc_error_desc except_reason
		en

		" FIXME: consider stateflag_found_tag too?
		" MAYBE: only do if we're going to display a message somehow
		if !(exists('proc_onnotfound_msg_desc') &&
				\	(!empty(proc_onnotfound_msg_desc)))
			let proc_onnotfound_msg_desc = 'tag could not be located'
		en
		let proc_onnotfound_msg_descsuff = ''
		if stateflag_proc_error &&
				\	exists('proc_error_desc') && (!empty(proc_error_desc))
			let proc_onnotfound_msg_descsuff = 'error: ' . proc_error_desc
		elsei !empty(proc_onnotfound_actiontaken_desc)
			let proc_onnotfound_msg_descsuff =
				\	'action: ' . proc_onnotfound_actiontaken_desc
		en
		if !empty(proc_onnotfound_msg_descsuff)
			let proc_onnotfound_msg_desc .=
				\	'; ' . proc_onnotfound_msg_descsuff
		en
		" TODO: (coditionally) show proc_onnotfound_msg_desc (if user chose to do
		" that, and !empty(proc_onnotfound_msg_desc)

		if exists('except_reason')
			" prev: throw printf('%s invalid kwargs.%s: %s', except_pref, 'gototag_data', except_reason)
			throw printf('%s %s', except_pref, except_reason)
		en

	endt

	retu stateflag_found_tag
endf

" }}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
