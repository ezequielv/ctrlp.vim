" =============================================================================
" File:          autoload/ctrlp.vim
" Description:   Fuzzy file, buffer, mru, tag, etc finder.
" Author:        CtrlP Dev Team
" Original:      Kien Nguyen <github.com/kien>
" Version:       1.80
" =============================================================================

" ** Static variables {{{1
" s:ignore() {{{2
fu! s:ignore()
	let igdirs = [
		\ '\.git',
		\ '\.hg',
		\ '\.svn',
		\ '_darcs',
		\ '\.bzr',
		\ '\.cdv',
		\ '\~\.dep',
		\ '\~\.dot',
		\ '\~\.nib',
		\ '\~\.plst',
		\ '\.pc',
		\ '_MTN',
		\ 'blib',
		\ 'CVS',
		\ 'RCS',
		\ 'SCCS',
		\ '_sgbak',
		\ 'autom4te\.cache',
		\ 'cover_db',
		\ '_build',
		\ ]
	let igfiles = [
		\ '\~$',
		\ '#.+#$',
		\ '[._].*\.swp$',
		\ 'core\.\d+$',
		\ '\.exe$',
		\ '\.so$',
		\ '\.bak$',
		\ '\.png$',
		\ '\.jpg$',
		\ '\.gif$',
		\ '\.zip$',
		\ '\.rar$',
		\ '\.tar\.gz$',
		\ ]
	retu {
		\ 'dir': '\v[\/]('.join(igdirs, '|').')$',
		\ 'file': '\v'.join(igfiles, '|'),
		\ }
endf
" Script local vars {{{2
let [s:pref, s:bpref, s:opts, s:new_opts, s:lc_opts] =
	\ ['g:ctrlp_', 'b:ctrlp_', {
	\ 'abbrev':                ['s:abbrev', {}],
	\ 'arg_map':               ['s:argmap', 0],
	\ 'buffer_func':           ['s:buffunc', {}],
	\ 'by_filename':           ['s:byfname', 0],
	\ 'custom_ignore':         ['s:usrign', s:ignore()],
	\ 'default_input':         ['s:deftxt', 0],
	\ 'dont_split':            ['s:nosplit', 'netrw'],
	\ 'dotfiles':              ['s:showhidden', 0],
	\ 'extensions':            ['s:extensions', []],
	\ 'follow_symlinks':       ['s:folsym', 0],
	\ 'highlight_match':       ['s:mathi', [1, 'CtrlPMatch']],
	\ 'jump_to_buffer':        ['s:jmptobuf', 'Et'],
	\ 'key_loop':              ['s:keyloop', 0],
	\ 'lazy_update':           ['s:lazy', 0],
	\ 'match_func':            ['s:matcher', {}],
	\ 'match_window':          ['s:mw', ''],
	\ 'match_window_bottom':   ['s:mwbottom', 1],
	\ 'match_window_reversed': ['s:mwreverse', 1],
	\ 'max_depth':             ['s:maxdepth', 40],
	\ 'max_files':             ['s:maxfiles', 10000],
	\ 'max_height':            ['s:mxheight', 10],
	\ 'max_history':           ['s:maxhst', exists('+hi') ? &hi : 20],
	\ 'mruf_default_order':    ['s:mrudef', 0],
	\ 'open_func':             ['s:openfunc', {}],
	\ 'open_multi':            ['s:opmul', '1v'],
	\ 'open_new_file':         ['s:newfop', 'v'],
	\ 'prompt_mappings':       ['s:urprtmaps', 0],
	\ 'regexp_search':         ['s:regexp', 0],
	\ 'root_markers':          ['s:rmarkers', []],
	\ 'split_window':          ['s:splitwin', 0],
	\ 'status_func':           ['s:status', {}],
	\ 'tabpage_position':      ['s:tabpage', 'ac'],
	\ 'use_caching':           ['s:caching', 1],
	\ 'user_command':          ['s:usrcmd', ''],
	\ 'validate':              ['s:validate', ''],
	\ 'working_path_mode':     ['s:pathmode', 'ra'],
	\ 'line_prefix':           ['s:lineprefix', '> '],
	\ 'open_single_match':     ['s:opensingle', []],
	\ 'brief_prompt':          ['s:brfprt', 0],
	\ 'match_current_file':    ['s:matchcrfile', 0],
	\ 'match_natural_name':    ['s:matchnatural', 0],
	\ 'compare_lim':           ['s:compare_lim', 3000],
	\ 'bufname_mod':           ['s:bufname_mod', ':t'],
	\ 'bufpath_mod':           ['s:bufpath_mod', ':~:.:h'],
	\ 'formatline_func':       ['s:flfunc', 's:formatline(v:val)'],
	\ 'user_command_async':    ['s:usrcmdasync', 0],
	\ }, {
	\ 'open_multiple_files':   's:opmul',
	\ 'regexp':                's:regexp',
	\ 'reuse_window':          's:nosplit',
	\ 'show_hidden':           's:showhidden',
	\ 'switch_buffer':         's:jmptobuf',
	\ }, {
	\ 'root_markers':          's:rmarkers',
	\ 'user_command':          's:usrcmd',
	\ 'working_path_mode':     's:pathmode',
	\ }]

" Global options
let s:glbs = { 'magic': 1, 'to': 1, 'tm': 0, 'sb': 1, 'hls': 0, 'im': 0,
	\ 'report': 9999, 'sc': 0, 'ss': 0, 'siso': 0, 'mfd': 200, 'ttimeout': 0,
	\ 'gcr': 'a:blinkon0', 'ic': 1, 'lmap': '', 'mousef': 0, 'imd': 1 }

" Keymaps
let [s:lcmap, s:prtmaps] = ['nn <buffer> <silent>', {
	\ 'PrtBS()':              ['<bs>', '<c-]>'],
	\ 'PrtDelete()':          ['<del>'],
	\ 'PrtDeleteWord()':      ['<c-w>'],
	\ 'PrtClear()':           ['<c-u>'],
	\ 'PrtSelectMove("j")':   ['<c-j>', '<down>'],
	\ 'PrtSelectMove("k")':   ['<c-k>', '<up>'],
	\ 'PrtSelectMove("t")':   ['<Home>', '<kHome>'],
	\ 'PrtSelectMove("b")':   ['<End>', '<kEnd>'],
	\ 'PrtSelectMove("u")':   ['<PageUp>', '<kPageUp>'],
	\ 'PrtSelectMove("d")':   ['<PageDown>', '<kPageDown>'],
	\ 'PrtHistory(-1)':       ['<c-n>'],
	\ 'PrtHistory(1)':        ['<c-p>'],
	\ 'AcceptSelection("e")': ['<cr>', '<2-LeftMouse>'],
	\ 'AcceptSelection("h")': ['<c-x>', '<c-cr>', '<c-s>'],
	\ 'AcceptSelection("t")': ['<c-t>'],
	\ 'AcceptSelection("v")': ['<c-v>', '<RightMouse>'],
	\ 'ToggleFocus()':        ['<s-tab>'],
	\ 'ToggleRegex()':        ['<c-r>'],
	\ 'ToggleByFname()':      ['<c-d>'],
	\ 'ToggleType(1)':        ['<c-f>', '<c-up>'],
	\ 'ToggleType(-1)':       ['<c-b>', '<c-down>'],
	\ 'PrtExpandDir()':       ['<tab>'],
	\ 'PrtInsert("c")':       ['<MiddleMouse>', '<insert>'],
	\ 'PrtInsert()':          ['<c-\>'],
	\ 'PrtCurStart()':        ['<c-a>'],
	\ 'PrtCurEnd()':          ['<c-e>'],
	\ 'PrtCurLeft()':         ['<c-h>', '<left>', '<c-^>'],
	\ 'PrtCurRight()':        ['<c-l>', '<right>'],
	\ 'PrtClearCache()':      ['<F5>'],
	\ 'PrtDeleteEnt()':       ['<F7>'],
	\ 'CreateNewFile()':      ['<c-y>'],
	\ 'MarkToOpen()':         ['<c-z>'],
	\ 'OpenMulti()':          ['<c-o>'],
	\ 'YankLine()':           [],
	\ 'ScreenRefresh()':      ['<c-_>'],
	\ 'PrtExit()':            ['<esc>', '<c-c>', '<c-g>'],
	\ }]

if 0 " TODO: remove (testing)
	function! s:PretendToMove()
		cal s:OnUpdatedState(0, 0)
		cal s:OnPrtCursorMoved()
	endfunction

	function! s:DoNothing()
	endfunction

	call extend(s:prtmaps, {
		\ 'PretendToMove()':      ['='],
		\ 'DoNothing()':          ['0'],
		\ }, "force")
endif

if !has('gui_running')
	cal add(s:prtmaps['PrtBS()'], remove(s:prtmaps['PrtCurLeft()'], 0))
en

let s:ficounts = {}

let s:ccex = s:pref.'clear_cache_on_exit'

" Regexp
let s:fpats = {
	\ '^\(\\|\)\|\(\\|\)$': '\\|',
	\ '^\\\(zs\|ze\|<\|>\)': '^\\\(zs\|ze\|<\|>\)',
	\ '^\S\*$': '\*',
	\ '^\S\\?$': '\\?',
	\ }

let s:has_conceal = has('conceal')
let s:bufnr_width = 3

" Keypad
let s:kprange = {
	\ 'Plus': '+',
	\ 'Minus': '-',
	\ 'Divide': '/',
	\ 'Multiply': '*',
	\ 'Point': '.',
	\ }

" Highlight groups
let s:hlgrps = {
	\ 'NoEntries': 'Error',
	\ 'Mode1': 'Character',
	\ 'Mode2': 'LineNr',
	\ 'Stats': 'Function',
	\ 'Match': 'Identifier',
	\ 'PrtBase': 'Comment',
	\ 'PrtText': 'Normal',
	\ 'PrtCursor': 'Constant',
	\ 'BufferNr':      'Constant',
	\ 'BufferInd':     'Normal',
	\ 'BufferHid':     'Comment',
	\ 'BufferHidMod':  'String',
	\ 'BufferVis':     'Normal',
	\ 'BufferVisMod':  'Identifier',
	\ 'BufferCur':     'Question',
	\ 'BufferCurMod':  'WarningMsg',
	\ 'BufferPath':    'Comment',
	\ }

" lname, sname of the basic(non-extension) modes
let s:types = ['fil', 'buf', 'mru']
if !exists('g:ctrlp_types')
	let g:ctrlp_types = s:types
el
	call filter(g:ctrlp_types, "index(['fil', 'buf', 'mru'], v:val)!=-1")
en
let g:ctrlp_builtins = len(g:ctrlp_types)-1

let s:coretype_names = {
	\ 'fil' : 'files',
	\ 'buf' : 'buffers',
	\ 'mru' : 'mru files',
	\ }

let s:coretypes = map(copy(g:ctrlp_types), '[s:coretype_names[v:val], v:val]')

" Get the options {{{2
fu! s:opts(...)
	unl! s:usrign s:usrcmd s:urprtmaps
	for each in ['byfname', 'regexp', 'extensions'] | if exists('s:'.each)
		let {each} = s:{each}
	en | endfo
	for [ke, va] in items(s:opts)
		let {va[0]} = exists(s:pref.ke) ? {s:pref.ke} : va[1]
	endfo
	unl va
	for [ke, va] in items(s:new_opts)
		let {va} = {exists(s:pref.ke) ? s:pref.ke : va}
	endfo
	unl va
	for [ke, va] in items(s:lc_opts)
		if exists(s:bpref.ke)
			unl {va}
			let {va} = {s:bpref.ke}
		en
	endfo
	" Match window options
	cal s:match_window_opts()
	" One-time values
	if a:0 && a:1 != {}
		unl va
		for [ke, va] in items(a:1)
			let opke = substitute(ke, '\(\w:\)\?ctrlp_', '', '')
			if has_key(s:lc_opts, opke)
				let sva = s:lc_opts[opke]
				unl {sva}
				let {sva} = va
			en
		endfo
	en
	for each in ['byfname', 'regexp'] | if exists(each)
		let s:{each} = {each}
	en | endfo
	if !exists('g:ctrlp_tilde_homedir') | let g:ctrlp_tilde_homedir = 0 | en
	if !exists('g:ctrlp_newcache') | let g:ctrlp_newcache = 0 | en
	let s:maxdepth = min([s:maxdepth, 100])
	let s:glob = s:showhidden ? '.*\|*' : '*'
	let s:igntype = empty(s:usrign) ? -1 : type(s:usrign)
	let s:lash = ctrlp#utils#lash()
	if s:keyloop
		let [s:lazy, s:glbs['imd']] = [0, 0]
	en
	unlet! s:ut_view s:ut_edit
	if s:lazy
		cal extend(s:glbs, { 'ut': ( s:lazy > 1 ? s:lazy : 250 ) })
		" by default, we will use a default delay in for s:ut_view
		let s:ut_view = get(g:, 'ctrlp_lazy_update_viewonly', 0)
		" map: 1 -> use default
		if s:ut_view == 1
			let s:ut_view = 75
		en
		let s:ut_edit = s:glbs.ut
		if s:ut_view >= s:ut_edit
			unlet! s:ut_view s:ut_edit
		en
	en
	" Extensions
	if !( exists('extensions') && extensions == s:extensions )
		for each in s:extensions
			exe 'ru autoload/ctrlp/'.each.'.vim'
		endfo
	en
	" Keymaps
	if type(s:urprtmaps) == 4
		cal extend(s:prtmaps, s:urprtmaps)
	en
endf

fu! s:match_window_opts()
	let s:mw_pos =
		\ s:mw =~ 'top\|bottom' ? matchstr(s:mw, 'top\|bottom') :
		\ exists('g:ctrlp_match_window_bottom') ? ( s:mwbottom ? 'bottom' : 'top' )
		\ : 'bottom'
	let s:mw_order =
		\ s:mw =~ 'order:[^,]\+' ? matchstr(s:mw, 'order:\zs[^,]\+') :
		\ exists('g:ctrlp_match_window_reversed') ? ( s:mwreverse ? 'btt' : 'ttb' )
		\ : 'btt'
	let s:mw_max =
		\ s:mw =~ 'max:[^,]\+' ? str2nr(matchstr(s:mw, 'max:\zs\d\+')) :
		\ exists('g:ctrlp_max_height') ? s:mxheight
		\ : 10
	let s:mw_min =
		\ s:mw =~ 'min:[^,]\+' ? str2nr(matchstr(s:mw, 'min:\zs\d\+')) : 1
	let [s:mw_max, s:mw_min] = [max([s:mw_max, 1]), max([s:mw_min, 1])]
	let s:mw_min = min([s:mw_min, s:mw_max])
	let s:mw_res =
		\ s:mw =~ 'results:[^,]\+' ? str2nr(matchstr(s:mw, 'results:\zs\d\+'))
		\ : min([s:mw_max, &lines])
endf
"}}}1
" * Open & Close {{{1
fu! s:Open()
	cal s:log(1)
	cal s:getenv()
	cal s:execextvar('enter')
	" FIXME: address the issue of a killed ControlP buffer (only when this has
	" been killed (say, when s:buffunc(1) does not return properly)).
	" MAYBE: call s:setupblank() before calling s:buffunc(1)?
	" MAYBE: try .. catch somewhere within this function to avoid swapfiles
	" creating annoying delays (the user has to blindly either press "esc"
	" several times, or (I guess) choose one of the "recovery" options).
	" IDEA: use the 'SwapExists' autocmd (pattern == 'ControlP'? (but do check
	" other things inside the autocmd command, as it's possible that other
	" buffers with that name might be created at some point)).
	sil! exe 'keepa' ( s:mw_pos == 'top' ? 'to' : 'bo' ) '1new ControlP'
	cal s:buffunc(1)
	let [s:bufnr, s:winw] = [bufnr('%'), winwidth(0)]
	let [s:focus, s:prompt] = [1, ['', '', '']]
	abc <buffer>
	if !exists('s:hstry')
		let hst = filereadable(s:gethistloc()[1]) ? s:gethistdata() : ['']
		let s:hstry = empty(hst) || !s:maxhst ? [''] : hst
	en
	for [ke, va] in items(s:glbs) | if exists('+'.ke)
		sil! exe 'let s:glb_'.ke.' = &'.ke.' | let &'.ke.' = '.string(va)
	en | endfo
	if s:opmul != '0' && has('signs')
		sign define ctrlpmark text=+> texthl=CtrlPMark
		hi def link CtrlPMark Search
	en
	cal s:setupblank()
endf

fu! s:Close()
	cal s:buffunc(0)
	if winnr('$') == 1
		bw!
	el
		try | bun!
		cat | clo! | endt
		cal s:unmarksigns()
	en
	for key in keys(s:glbs) | if exists('+'.key)
		sil! exe 'let &'.key.' = s:glb_'.key
	en | endfo
	if exists('s:glb_acd') | let &acd = s:glb_acd | en
	let g:ctrlp_lines = []
	if s:winres[1] >= &lines && s:winres[2] == winnr('$')
		exe s:winres[0].s:winres[0]
	en
	" NOTE: 's:last_invocation_env_dict' depends on 's:init', so it's safe to
	" ':unlet' it here.
	unl! s:focus s:hisidx s:hstgot s:marked s:statypes s:init s:savestr
		\ s:mrbs s:did_exp s:last_invocation_env_dict s:first_statusline_update
		\ s:matcher_run_success
	cal ctrlp#recordhist()
	cal s:execextvar('exit')
	cal s:log(0)
	let v:errmsg = s:ermsg
	ec
endf
" * Clear caches {{{1
fu! ctrlp#clr(...)
	let [s:matches, g:ctrlp_new{ a:0 ? a:1 : 'cache' }] = [1, 1]
endf

fu! ctrlp#clra()
	let cadir = ctrlp#utils#cachedir()
	if isdirectory(cadir)
		let cafiles = split(s:glbpath(s:fnesc(cadir, 'g', ','), '**', 1), "\n")
		let eval = '!isdirectory(v:val) && v:val !~ ''\v[\/]cache[.a-z]+$|\.log$'''
		sil! cal map(s:ifilter(cafiles, eval), 'delete(v:val)')
	en
	cal ctrlp#clr()
endf

fu! s:Reset(args)
	let opts = has_key(a:args, 'opts') ? [a:args['opts']] : []
	cal call('s:opts', opts)
	cal s:autocmds()
	cal ctrlp#utils#opts()
	cal s:execextvar('opts')
endf
" * Files {{{1
fu! ctrlp#files()
	let cafile = ctrlp#utils#cachefile()
	if g:ctrlp_newcache || !filereadable(cafile) || s:nocache(cafile)
		let [lscmd, s:initcwd, g:ctrlp_allfiles] = [s:lsCmd(), s:dyncwd, []]
		" Get the list of files
		if empty(lscmd)
			if !ctrlp#igncwd(s:dyncwd)
				cal s:InitCustomFuncs()
				cal s:GlobPath(s:fnesc(s:dyncwd, 'g', ','), 0)
				cal s:CloseCustomFuncs()
			en
		el
			sil! cal ctrlp#progress('Indexing...')
			try | cal s:UserCmd(lscmd)
			cat | retu [] | endt
		en
		" Remove base directory
		cal ctrlp#rmbasedir(g:ctrlp_allfiles)
		if len(g:ctrlp_allfiles) <= s:compare_lim
			cal sort(g:ctrlp_allfiles, 'ctrlp#complen')
		en
		cal s:writecache(cafile)
		let catime = getftime(cafile)
	el
		let catime = getftime(cafile)
		if !( exists('s:initcwd') && s:initcwd == s:dyncwd )
			\ || get(s:ficounts, s:dyncwd, [0, catime])[1] != catime
			let s:initcwd = s:dyncwd
			let g:ctrlp_allfiles = ctrlp#utils#readfile(cafile)
		en
	en
	cal extend(s:ficounts, { s:dyncwd : [len(g:ctrlp_allfiles), catime] })
	retu g:ctrlp_allfiles
endf

fu! s:InitCustomFuncs()
	if s:igntype == 4 && has_key(s:usrign, 'func-init') && s:usrign['func-init'] != ''
		exe call(s:usrign['func-init'], [])
	en
endf

fu! s:CloseCustomFuncs()
	if s:igntype == 4 && has_key(s:usrign, 'func-close') && s:usrign['func-close'] != ''
		exe call(s:usrign['func-close'], [])
	en
endf

fu! s:GlobPath(dirs, depth)
	let entries = split(globpath(a:dirs, s:glob), "\n")
	let [dnf, depth] = [ctrlp#dirnfile(entries), a:depth + 1]
	cal extend(g:ctrlp_allfiles, dnf[1])
	if !empty(dnf[0]) && !s:maxf(len(g:ctrlp_allfiles)) && depth <= s:maxdepth
		sil! cal ctrlp#progress(len(g:ctrlp_allfiles), 1)
		cal s:GlobPath(join(map(dnf[0], 's:fnesc(v:val, "g", ",")'), ','), depth)
	en
endf

fu! ctrlp#addfile(ch, file)
	call add(g:ctrlp_allfiles, a:file)
	cal s:OnUpdatedState(0, 1)
endf

fu! s:safe_printf(format, ...)
	try
		retu call('printf', [a:format] + a:000)
	cat
		retu a:format
	endt
endf

fu! s:UserCmd(lscmd)
	let [path, lscmd] = [s:dyncwd, a:lscmd]
	let do_ign =
		\ type(s:usrcmd) == 4 && has_key(s:usrcmd, 'ignore') && s:usrcmd['ignore']
	if do_ign && ctrlp#igncwd(s:cwd) | retu | en
	if exists('+ssl') && &ssl && &shell !~ 'sh'
		let [ssl, &ssl, path] = [&ssl, 0, tr(path, '/', '\')]
	en
	if (has('win32') || has('win64')) && match(&shellcmdflag, "/") != -1
		let lscmd = substitute(lscmd, '\v(^|\&\&\s*)\zscd (/d)@!', 'cd /d ', '')
	en
	let path = ctrlp#utils#shellescape(path)
	if (has('win32') || has('win64')) && match(&shell, 'sh') != -1
		let path = tr(path, '\', '/')
	en
	if s:usrcmdasync && v:version >= 800 && exists('*job_start')
		if exists('s:job')
			call job_stop(s:job)
		en
		let g:ctrlp_allfiles = []
		let s:job = job_start([&shell, &shellcmdflag, printf(lscmd, path)], {'callback': 'ctrlp#addfile'})
	elsei has('patch-7.4-597') && !(has('win32') || has('win64'))
		let g:ctrlp_allfiles = systemlist(s:safe_printf(lscmd, path))
	el
		let g:ctrlp_allfiles = split(system(s:safe_printf(lscmd, path)), "\n")
	en
	"- DEBUG: verbose echomsg printf( 'DEBUG: s:UserCmd(): cmd=%s; output=%s', string(lscmd), string(g:ctrlp_allfiles))
	if exists('+ssl') && exists('ssl')
		let &ssl = ssl
		cal map(g:ctrlp_allfiles, 'tr(v:val, "\\", "/")')
	en
	if exists('s:vcscmd') && s:vcscmd
		cal map(g:ctrlp_allfiles, 'tr(v:val, "/", "\\")')
	en
	if do_ign
		if !empty(s:usrign)
			let g:ctrlp_allfiles = ctrlp#dirnfile(g:ctrlp_allfiles)[1]
		en
		if &wig != ''
			cal filter(g:ctrlp_allfiles, 'glob(v:val) != ""')
		en
	en
endf

fu! s:lsCmd()
	let cmd = s:usrcmd
	if type(cmd) == 1
		retu cmd
	elsei type(cmd) == 3 && len(cmd) >= 2 && cmd[:1] != ['', '']
		if s:findroot(s:dyncwd, cmd[0], 0, 1) == []
			retu len(cmd) == 3 ? cmd[2] : ''
		en
		let s:vcscmd = s:lash == '\'
		retu cmd[1]
	elsei type(cmd) == 4 && ( has_key(cmd, 'types') || has_key(cmd, 'fallback') )
		let fndroot = []
		if !empty(get(cmd, 'types'))
			" NOTE: allow s:usrcmd (g:ctrlp_user_command) ['types'] to be either a
			" dictionary (backwards-compatible) for which the keys are not used, or
			" just a list, which gives a guaranteed processing order (to
			" s:findroot()) and therefore to the result of this function.
			let [markrs, cmdtypes] = [[], ((type(cmd['types']) == 4) ? values(cmd['types']) : cmd['types'])]
			for pair in cmdtypes
				cal add(markrs, pair[0])
			endfo
			let fndroot = s:findroot(s:dyncwd, markrs, 0, 1)
		en
		if fndroot == []
			retu has_key(cmd, 'fallback') ? cmd['fallback'] : ''
		en
		for pair in cmdtypes
			if pair[0] == fndroot[0] | brea | en
		endfo
		let s:vcscmd = s:lash == '\'
		"- DEBUG: verbose echomsg 'DEBUG: s:lsCmd(): returning: ' . string(pair[1]) | call sleep(5)
		retu pair[1]
	en
endf
" - Buffers {{{1
let s:bufparts_bpath_truncate = [ '', '.' ]
fu! s:bufparts(bufnr)
	let idc  = (a:bufnr == bufnr('#')      ? '#' : '')  " alternative
	let idc .= (getbufvar(a:bufnr, '&mod') ? '+' : '')  " modified
	let idc .= (getbufvar(a:bufnr, '&ma')  ? '' : '-')  " nomodifiable
	let idc .= (getbufvar(a:bufnr, '&ro')  ? '=' : '')  " readonly

	" flags for highlighting
	let hiflags  = (bufwinnr(a:bufnr) != -1    ? '*' : '')  " visible
	let hiflags .= (getbufvar(a:bufnr, '&mod') ? '+' : '')  " modified
	let hiflags .= (a:bufnr == s:crbufnr       ? '!' : '')  " current

	let bname = bufname(a:bufnr)

	if empty(s:bufpath_mod) || empty(bname)
		let bpath = ''
	el
		let bpath = fnamemodify(bname, s:bufpath_mod)
		" fixed: when the file is relative to the current directory, we don't want
		" to have bpath == '.' and then add the '/', as that would clash with
		" other uses of the ':.' filename-modifier (fnamemodify()) scattered
		" around this file.
		if index(s:bufparts_bpath_truncate, bpath) >= 0
			let bpath = ''
		el
			let bpath .= s:lash(bpath)
		en
	en

	let bname = (empty(bname) ? '[No Name]' : fnamemodify(bname, s:bufname_mod))

	" DEBUG: cal ctrlp#ev_log_printf( 's:bufparts(): bname=%s; bpath=%s', string(bname), string(bpath) )
	retu [idc, hiflags, bname, bpath]
endf

" note: a:parts is the value returned from s:bufparts()
fu! s:getpathamefrombufparts(parts)
	let bufdir = a:parts[3]
	let buffname = a:parts[2]
	" note: bufdir is either empty or it ends with a s:lash
	retu bufdir . buffname
endf

" optional arguments:
"  query_type:
"   'id': return ids instead of the expanded "items" to be part of g:ctrlp_lines
"   ('items'[/other values]: items)
fu! ctrlp#buffers(...)
	let filter_expr =
				\ '(empty(getbufvar(v:val, "&bt")) || s:isterminal(v:val)) ' .
				\   '&& getbufvar(v:val, "&bl")'
	" NOTE: allow the input 'source_bufnr_list' to include the current buffer.
	if !s:matchcrfile
		let curbufnr = s:crbufnr
		let filter_expr .= ' && (v:val !=# curbufnr)'
	en
	let ids = sort(filter(range(1, bufnr('$')), filter_expr), 's:compmreb')
	if a:0 && a:1 == 'id'
		retu ids
	el
		let bufs = [[], []]
		for id in ids
			let bname = bufname(id)
			let ebname = bname == ''
			let fname = ebname ? '['.id.'*No Name]' : s:getpathamefrombufparts(s:bufparts(id))
			cal add(bufs[ebname], fname)
		endfo
		retu bufs[0] + bufs[1]
	en
endf
" * MatchedItems() {{{1
fu! s:MatchIt(items, pat, limit, exc)
	let [lines, id] = [[], 0]
	let pat =
		\ s:byfname() ? map(split(a:pat, '^[^;]\+\\\@<!\zs;', 1), 's:martcs.v:val')
		\ : s:martcs.a:pat
	for item in a:items
		let id += 1
		try
			if (s:matchcrfile || !( s:ispath && item ==# a:exc )) &&
						\call(s:mfunc, [item, pat]) >= 0
				cal add(lines, item)
			en
		cat | brea | endt
		if a:limit > 0 && len(lines) >= a:limit | brea | en
	endfo
	let s:mdata = [s:dyncwd, s:itemtype, s:regexp, s:sublist(a:items, id, -1)]
	" DEBUG: cal ctrlp#ev_log_printf( 'DEBUG: s:MatchIt(): len(a:items)=%d; len(lines)=%d; a:exc=%s; a:items=%s', len(a:items), len(lines), string(a:exc), string(a:items) )
	retu lines
endf

fu! s:MatchedItems(items, pat, limit)
	let log_pref = 's:MatchedItems([..]): '
	let exc = (exists('s:crfilerel') && s:curtype() != 'buf') ? s:crfilerel : ''
	let items = s:narrowable() ? s:matched + s:mdata[3] : a:items
	wh !0
		let matcher = s:getextvar('matcher')
		if empty(matcher) || type(matcher) != 4 || !has_key(matcher, 'match')
			unl matcher
			let matcher = s:matcher
		en
		if !get(s:, 'matcher_run_success', !0)
			unl matcher
			let matcher = {}
		en
		if matcher != {}
			try
				let argms =
					\ has_key(matcher, 'arg_type') && matcher['arg_type'] == 'dict' ? [{
					\ 'items':  items,
					\ 'str':    a:pat,
					\ 'limit':  a:limit,
					\ 'mmode':  s:mmode(),
					\ 'ispath': s:ispath,
					\ 'crfile': exc,
					\ 'regex':  s:regexp,
					\ }] : [items, a:pat, a:limit, s:mmode(), s:ispath, exc, s:regexp]
				let lines = call(matcher['match'], argms, matcher)
				let s:matcher_run_success = !0
			cat
				let s:matcher_run_success = 0
				" TODO: report error (v:errmsg, v:exception, etc.) consistently (other
				" ctrlp function?)
				" prev: \		'v:exception=%s; v:errmsg=%s; matcher=%s;',
				" prev:	\	string(v:exception), string(v:errmsg), string(matcher))
				cal ctrlp#ev_log_printf(
					\	log_pref . 'running the matcher raised an exception. ' .
					\		'v:exception=%s; v:throwpoint=%s; matcher=%s;',
					\	string(v:exception), string(v:throwpoint), string(matcher))
				con
			endt
		el
			let lines = s:MatchIt(items, a:pat, a:limit, exc)
		en
		brea
	endw
	let s:matches = len(lines)
	cal ctrlp#ev_log_printf(
		\ log_pref . 'len(a:items)=%d; a:pat=%s; a:limit=%s; ' .
		\		'matcher=%s; len(lines)=%d; lines[0]=%s;',
		\	len(a:items), string(a:pat), string(a:limit),
		\	string(matcher), len(lines), string(get(lines, 0, '<<empty>>')))
	unl! s:did_exp
	retu lines
endf

fu! s:SplitPattern(str)
	let str = a:str
	if s:regexp
		let pat = s:regexfilter(str)
	el
		let lst = split(str, '\zs')
		if exists('+ssl') && !&ssl
			cal map(lst, 'escape(v:val, ''\'')')
		en
		for each in ['^', '$', '.']
			cal map(lst, 'escape(v:val, each)')
		endfo
	en
	if exists('lst')
		let pat = ''
		if !empty(lst)
			if s:byfname() && index(lst, ';') > 0
				let fbar = index(lst, ';')
				let lst_1 = s:sublist(lst, 0, fbar - 1)
				let lst_2 = len(lst) - 1 > fbar ? s:sublist(lst, fbar + 1, -1) : ['']
				let pat = s:buildpat(lst_1).';'.s:buildpat(lst_2)
			el
				let pat = s:buildpat(lst)
			en
		en
	en
	retu escape(pat, '~')
endf
" * OnUpdatedState() {{{1
fu! s:Render(lines, pat)
	let [&ma, lines, s:res_count] = [1, a:lines, len(a:lines)]
	let height = min([max([s:mw_min, s:res_count]), s:winmaxh])
	let pat = s:byfname() ? split(a:pat, '^[^;]\+\\\@<!\zs;', 1)[0] : a:pat
	let cur_cmd = 'keepj norm! '.( s:mw_order == 'btt' ? 'G' : 'gg' ).'1|'

	" Setup the match window
	sil! exe '%d _ | res' height
	" Print the new items
	if empty(lines)
		let [s:matched, s:lines] = [[], []]
		let lines = [' == NO ENTRIES ==']
		cal setline(1, s:offset(lines, height - 1))
		setl noma nocul
		exe cur_cmd
		cal s:unmarksigns()
		if s:dohighlight() | cal clearmatches() | en
		retu
	en
	let s:matched = copy(lines)
	" Sorting
	if !s:nosort()
		let s:compat = s:martcs.pat
		cal sort(lines, 's:mixedsort')
		unl s:compat
	en
	if s:mw_order == 'btt' | cal reverse(lines) | en
	let s:lines = copy(lines)
	cal map(lines, s:flfunc)
	cal setline(1, s:offset(lines, height))
	cal s:unmarksigns()
	cal s:remarksigns()
	" Highlighting
	" orig: if s:dohighlight()
	" TODO: do this better (runtime toggle (add keyboard mapping))
	"-? if s:dohighlight() && get(g:, 'ctrlp_match_highlight', 1)
	if s:dohighlight()
		cal s:highlight(pat, s:mathi[1])
	en
	setl noma cul
	exe cur_cmd
endf

fu! s:Update(str)
	let log_pref = 's:Update(str): '
	" Get the new string sans tail
	let str = s:sanstail(a:str)
	cal ctrlp#ev_log_printf(
		\ log_pref . 'entered. ' .
		\		'str=%s;', string(str))
	" Optionally send the string to a custom validate function
	if s:validate != '' | let str = call(s:validate, [str]) | en

	" prev: " Get the previous string if existed
	" prev: let oldstr = exists('s:savestr') ? s:savestr : ''
	" prev: " Stop if the string's unchanged
	" prev: if str == oldstr && !empty(str) && !exists('s:force') | retu | en
	" prev: let s:savestr = str
	" Stop if the string's unchanged, or if it's the first time this function
	" gets called (so it needs to return a suitable 'lines' list).
	if exists('s:savestr') && str == s:savestr && !exists('s:force') | retu | en
	let s:savestr = str

	let s:martcs = &scs && str =~ '\u' ? '\C' : ''
	" MAYBE: TODO: would we need to also create a "highlighter-friendly" version
	" of the input 'str' that will be used by vim to produce the matches?
	let pat = s:matcher == {} ? s:SplitPattern(str) : str
	let lines = s:nolim == 1 && empty(str) ? copy(g:ctrlp_lines)
		\ : s:MatchedItems(g:ctrlp_lines, pat, s:mw_res)
	cal ctrlp#ev_log_printf(
		\	log_pref . 'retrieved lines. ' .
		\		'len(lines)=%d; s:nolim=%d;',
		\	len(lines), s:nolim)
	if empty(str) | cal clearmatches() | en
	cal s:Render(lines, pat)
	cal ctrlp#ev_log_printf(
		\	log_pref . 'about to return. ' .
		\		'len(lines)=%d;',
		\	len(lines))
	return lines
endf

if exists('*getcurpos')
	fu! s:GetCurrentCursorPos()
		return getcurpos()
	endf
el
	fu! s:GetCurrentCursorPos()
		return getpos('.')
	endf
en

" TODO: call this later (replace calls to s:GetCurrentCursorPos() and setpos()
" with these, etc.) {{{
fu! s:GetWinCursorState()
	let cursor_pos = s:GetCurrentCursorPos()
	let wincurstate = {
				\ 'cursor_pos': cursor_pos,
				\ }

	sil keepj normal! H0
	let wincurstate.win_h_pos = s:GetCurrentCursorPos()

	cal setpos('.', cursor_pos)

	return wincurstate
endf

fu! s:SetWinCursorState(wincurstate)
	cal setpos('.', a:wincurstate.win_h_pos)
	sil! normal! zt
	cal setpos('.', a:wincurstate.cursor_pos)
endf
" }}}

fu! s:ForceUpdate()
	let wincrstate = s:GetWinCursorState()
	" NOTE: see also (':help'): winheight(), 'winheight', 'winminheight'
	let wh = &wh
	let &wh = winheight(0)

	sil! cal s:Update(escape(s:getinput(), '\'))

	cal s:SetWinCursorState(wincrstate)
	let &wh = wh

	cal s:OnUpdatedState(0, 0)
endf

" MAYBE: refactor to use the winnr == 0 as a special case for not calling
" winnr() at all (thus reducing the number of interactions with vim's
" state/windowing system, etc.).
fu! s:SetWinHeight(height, ...)
	let winnr = a:0 ? a:1 : 0
	if winheight(winnr) == a:height | retu 0 | en
	let [gotowin_cmd_pref, gotowin_cmd_suff] = ['sil ', 'winc w']
	try
		let winnr_orig = winnr()
		" prev: if (winnr != 0) && (winnr == winnr()) | let winnr = 0 | en
		" prev: if (winnr != 0) && (winnr == winnr_orig) | let winnr = 0 | en
		if winnr == 0 | let winnr = winnr_orig | en
		" prev: if winnr != 0
		if winnr != winnr_orig
			exe gotowin_cmd_pref . winnr . gotowin_cmd_suff
		en
		exe a:height . 'winc _'
		retu 1
	fina
		if winnr() != winnr_orig
			exe gotowin_cmd_pref . winnr_orig . gotowin_cmd_suff
		en
	endt
endf

" TODO: make these parameters mandatory (they're currently specified on every call)
" optional args: upd_gsts, upd_str
" * upd_gsts: default: 0
" * upd_str: default: 0
fu! s:OnUpdatedState(...)
	let log_pref = 's:OnUpdatedState(): '
	let upd_gsts = a:0 > 0 ? a:1 : 0
	let upd_str = a:0 > 1 ? a:2 : 0
	let base = ( s:regexp ? 'r' : '>' ).( s:byfname() ? 'd' : '>' ).'> '
	let str = escape(s:getinput(), '\')
	let lazy = s:lazy && !exists('s:force') && has('autocmd')
	cal ctrlp#ev_log_printf(
		\ log_pref . 'entered. ' .
		\		'upd_gsts=%d; upd_str=%d; base=%s; str=%s; lazy=%d;',
		\	upd_gsts, upd_str, string(base), string(str), lazy)
	if upd_str && (!lazy || empty(str)) && ( s:matches || s:regexp || exists('s:did_exp')
		\ || str =~ '\(\\\(<\|>\)\|[*|]\)\|\(\\\:\([^:]\|\\:\)*$\)' )
		cal ctrlp#ev_log_printf(
			\	log_pref . 'about to call s:Update(str). ' .
			\		'str=%s; lazy=%d; s:matches=%d; s:regexp=%s; s:did_exp=%s;',
			\	string(str), lazy, s:matches,
			\	get( s:, 'regexp', '<unset>'),
			\	get( s:, 'did_exp', '<unset>'))
		sil! cal s:Update(str)
	en
	if upd_gsts
		cal ctrlp#ev_log_printf(log_pref . 'about to call ctrlp#statusline()')
		sil! cal ctrlp#statusline()
	en
	" Toggling
	let [hiactive, hicursor, base] = s:focus
		\ ? ['CtrlPPrtText', 'CtrlPPrtCursor', base]
		\ : ['CtrlPPrtBase', 'CtrlPPrtBase', tr(base, '>', '-')]
	let hibase = 'CtrlPPrtBase'
	if !lazy || upd_gsts || get(s:, 'ut_view', &ut) == 0
		" prev: cal ctrlp#ev_log_printf('s:OnUpdatedState(): about to execute :redraw command')
		" prev: redr
		"-? cal ctrlp#ev_log_printf('s:OnUpdatedState(): about to execute :redrawstatus command')
		"-? redraw! | redrawstatus!
		"? cal ctrlp#ev_log_printf('s:OnUpdatedState(): about to execute :redraw command')
		"? try
		"? 	let lazyredraw_save = &lazyredraw
		"? 	verbose redr
		"? finally
		"? 	let &lazyredraw = lazyredraw_save
		"? endtry
		"? cal ctrlp#ev_log_printf('s:OnUpdatedState(): about to execute :redraw command')
		"? verbose redraw! | verbose redrawstatus!
		if !get(s:, 'first_statusline_update')
			let s:first_statusline_update = 1
			if get(g:, 'ctrlp_issue_initstatuslinenotupdated_workaround')
				cal ctrlp#ev_log_printf(log_pref . 'first ctrlp window update issue: workaround: simulating keyboard input. attempting to find a suitable keyboard mapping.')

				" choose from a number of candidate mapping keys as candidates, in
				" order.
				" prev: \		[ 'ToggleByFname()', 2 ],
				for [ kmap_key, kmap_count ] in [
					\		[ 'ScreenRefresh()', 1 ],
					\		[ 'ToggleRegex()', 2 ],
					\	]
					unl! keystrokes
					" prev: let keystrokes = get(s:prtmaps['ToggleByFname()'], 0, '')
					let keystrokes = get(s:prtmaps[kmap_key], 0, '')
					" prev: if !empty(keystrokes)
					if keystrokes =~# '^<[^<]*>\s*$'
						let keystrokes_orig = keystrokes
						" TODO: create a function to detect single-character sequences after
						" resolving the mapping keysequence to vim's internal keystroke
						" representation (see ':h expr-quote').
						let keystrokes = eval('"' . escape(keystrokes, '<') . '"')
						" TODO: improve on this check.
						" for now, we cheaply make sure that the sequence we're sending to
						" feedkeys() consists of a single character, which is to be made of
						" a "\<key>" sequence.
						if len(keystrokes) == 1
							cal ctrlp#ev_log_printf(
								\	log_pref . ' using keyboard mapping %s, count=%d',
								\	string(keystrokes_orig), kmap_count)
							" prev: cal feedkeys(keystrokes . keystrokes)
							cal feedkeys(repeat(keystrokes, kmap_count))
							brea
						en
					en
				endfo
			elsei 0
				cal ctrlp#ev_log_printf(log_pref . 'first ctrlp window update: trying to force a statusline update')
				try
					let wincrstate = s:GetWinCursorState()
					let [wh_save, wh_this_save] = [&wh, winheight(0)]

					let wh_temp = (wh_this_save == 1) ? 2 : 1
					" MAYBE: set zero, one, or something else?
					let &wh = wh_temp
					"? let changed_wh = s:SetWinHeight(wh_temp)
					cal s:SetWinHeight(wh_temp)

				fina
					if exists('wh_save') | let &wh = wh_save | en
					if exists('wh_this_save') | cal s:SetWinHeight(wh_this_save) | en
					if exists('wincrstate') | cal s:SetWinCursorState(wincrstate) | en
				endt
			en
		el
			cal ctrlp#ev_log_printf(log_pref . 'about to execute :redraw command')
			redr
		en
	en
	" Build it
	let prt = copy(s:prompt)
	cal map(prt, 'escape(v:val, ''"\'')')
	exe 'echoh' hibase '| echon "'.base.'"
		\ | echoh' hiactive '| echon "'.prt[0].'"
		\ | echoh' hicursor '| echon "'.prt[1].'"
		\ | echoh' hiactive '| echon "'.prt[2].'" | echoh None'
	" Append the cursor at the end
	if empty(prt[1]) && s:focus
		exe 'echoh' hibase '| echon "_" | echoh None'
	en
	cal ctrlp#ev_log_printf(log_pref . 'returning normally')
endf

" map-friendly version (no parameters)
fu! s:ScreenRefresh()
	" MAYBE: specify 1 for upd_str, too.
	cal s:OnUpdatedState(1, 0)
endf
" - OnPrtCursorMoved()/OnPrtStrValueEdited() {{{1
fu! s:OnPrtCursorMoved()
	let ut_view = get(s:, 'ut_view', &ut)
	if ut_view == 0 || ut_view == &ut | retu | en
	let &ut = ut_view
endf

fu! s:OnPrtStrValueEdited()
	if get(s:, 'ut_edit', &ut) == &ut | retu | en
	let &ut = s:ut_edit
endf
" - SetDefTxt() {{{1
fu! s:SetDefTxt()
	if s:deftxt == '0' || ( s:deftxt == 1 && !s:ispath ) | retu | en
	let txt = s:deftxt
	if !type(txt)
		let path = s:crfpath.s:lash(s:crfpath)
		let txt = txt && !stridx(path, s:dyncwd) ? ctrlp#rmbasedir([path])[0] : ''
	en
	let s:prompt[0] = txt
endf
" ** Prt Actions {{{1
" Editing {{{2
fu! s:PrtClear()
	if !s:focus | retu | en
	unl! s:hstgot
	let [s:prompt, s:matches] = [['', '', ''], 1]
	cal s:OnUpdatedState(0, 1)
	cal s:OnPrtStrValueEdited()
endf

fu! s:PrtAdd(char)
	unl! s:hstgot
	let s:act_add = 1
	let s:prompt[0] .= a:char
	cal s:OnUpdatedState(0, 1)
	cal s:OnPrtStrValueEdited()
	unl s:act_add
endf

fu! s:PrtBS()
	if !s:focus | retu | en
	if empty(s:prompt[0]) && s:brfprt != 0
		cal s:PrtExit()
		retu
	en
	unl! s:hstgot
	let [s:prompt[0], s:matches] = [substitute(s:prompt[0], '.$', '', ''), 1]
	cal s:OnUpdatedState(0, 1)
	cal s:OnPrtStrValueEdited()
endf

fu! s:PrtDelete()
	if !s:focus | retu | en
	unl! s:hstgot
	let [prt, s:matches] = [s:prompt, 1]
	let prt[1] = matchstr(prt[2], '^.')
	let prt[2] = substitute(prt[2], '^.', '', '')
	cal s:OnUpdatedState(0, 1)
	cal s:OnPrtStrValueEdited()
endf

fu! s:PrtDeleteWord()
	if !s:focus | retu | en
	unl! s:hstgot
	let [str, s:matches] = [s:prompt[0], 1]
	let str = str =~ '\W\w\+$' ? matchstr(str, '^.\+\W\ze\w\+$')
		\ : str =~ '\w\W\+$' ? matchstr(str, '^.\+\w\ze\W\+$')
		\ : str =~ '\s\+$' ? matchstr(str, '^.*\S\ze\s\+$')
		\ : str =~ '\v^(\S+|\s+)$' ? '' : str
	let s:prompt[0] = str
	cal s:OnUpdatedState(0, 1)
	cal s:OnPrtStrValueEdited()
endf

fu! s:PrtInsert(...)
	if !s:focus | retu | en
	let type = !a:0 ? '' : a:1
	if !a:0
		let type = s:insertstr()
		if type == 'cancel' | retu | en
	en
	if type ==# 'r'
		let regcont = s:getregs()
		if regcont < 0 | retu | en
	en
	unl! s:hstgot
	let s:act_add = 1
	let s:prompt[0] .= type ==# 'w' ? s:crword
		\ : type ==# 'f' ? s:crgfile
		\ : type ==# 's' ? s:regisfilter('/')
		\ : type ==# 'v' ? s:crvisual
		\ : type ==# 'c' ? s:regisfilter('+')
		\ : type ==# 'r' ? regcont : ''
	cal s:OnUpdatedState(0, 1)
	cal s:OnPrtStrValueEdited()
	unl s:act_add
endf

fu! s:PrtExpandDir()
	if !s:focus | retu | en
	let str = s:getinput('c')
	if str =~ '\v^\@(cd|lc[hd]?|chd)\s.+' && s:spi
		let hasat = split(str, '\v^\@(cd|lc[hd]?|chd)\s*\zs')
		let str = get(hasat, 1, '')
		if str =~# '\v^[~$]\i{-}[\/]?|^#(\<?\d+)?:(p|h|8|\~|\.|g?s+)'
			let str = expand(s:fnesc(str, 'g'))
		elsei str =~# '\v^(\%|\<c\h{4}\>):(p|h|8|\~|\.|g?s+)'
			let spc = str =~# '^%' ? s:crfile
				\ : str =~# '^<cfile>' ? s:crgfile
				\ : str =~# '^<cword>' ? s:crword
				\ : str =~# '^<cWORD>' ? s:crnbword : ''
			let pat = '(:(p|h|8|\~|\.|g?s(.)[^\3]*\3[^\3]*\3))+'
			let mdr = matchstr(str, '\v^[^:]+\zs'.pat)
			let nmd = matchstr(str, '\v^[^:]+'.pat.'\zs.{-}$')
			let str = fnamemodify(s:fnesc(spc, 'g'), mdr).nmd
		en
	en
	if str == '' | retu | en
	unl! s:hstgot
	let s:act_add = 1
	let [base, seed] = s:headntail(str)
	if str =~# '^[\/]'
		let base = expand('/').base
	en
	let dirs = s:dircompl(base, seed)
	if len(dirs) == 1
		let str = dirs[0]
	elsei len(dirs) > 1
		let str .= s:findcommon(dirs, str)
	en
	let s:prompt[0] = exists('hasat') ? hasat[0].str : str
	cal s:OnUpdatedState(0, 1)
	cal s:OnPrtStrValueEdited()
	unl s:act_add
endf
" Movement {{{2
fu! s:PrtCurLeft()
	if !s:focus | retu | en
	let prt = s:prompt
	if !empty(prt[0])
		let s:prompt = [substitute(prt[0], '.$', '', ''), matchstr(prt[0], '.$'),
			\ prt[1] . prt[2]]
	en
	cal s:OnUpdatedState(0, 0)
	cal s:OnPrtCursorMoved()
endf

fu! s:PrtCurRight()
	if !s:focus | retu | en
	let prt = s:prompt
	let s:prompt = [prt[0] . prt[1], matchstr(prt[2], '^.'),
		\ substitute(prt[2], '^.', '', '')]
	cal s:OnUpdatedState(0, 0)
	cal s:OnPrtCursorMoved()
endf

fu! s:PrtCurStart()
	if !s:focus | retu | en
	let str = join(s:prompt, '')
	let s:prompt = ['', matchstr(str, '^.'), substitute(str, '^.', '', '')]
	cal s:OnUpdatedState(0, 0)
	cal s:OnPrtCursorMoved()
endf

fu! s:PrtCurEnd()
	if !s:focus | retu | en
	let s:prompt = [join(s:prompt, ''), '', '']
	cal s:OnUpdatedState(0, 0)
	cal s:OnPrtCursorMoved()
endf

fu! s:PrtSelectMove(dir)
	let dirs = {'t': 'gg','b': 'G','j': 'j','k': 'k','u': "\<C-b>",'d': "\<C-f>"}
	exe 'keepj norm!' dirs[a:dir]
	let wincrstate = s:GetWinCursorState()
	cal s:OnUpdatedState(0, 0)
	cal s:OnPrtCursorMoved()
	cal s:SetWinCursorState(wincrstate)
endf

fu! s:PrtSelectJump(char)
	let lines = copy(s:lines)
	if s:byfname()
		cal map(lines, 'split(v:val, ''[\/]\ze[^\/]\+$'')[-1]')
	en
	" Cycle through matches, use s:jmpchr to store last jump
	let chr = escape(matchstr(a:char, '^.'), '.~')
	let smartcs = &scs && chr =~ '\u' ? '\C' : ''
	if match(lines, smartcs.'^'.chr) >= 0
		" If not exists or does but not for the same char
		let pos = match(lines, smartcs.'^'.chr)
		if !exists('s:jmpchr') || ( exists('s:jmpchr') && s:jmpchr[0] != chr )
			let [jmpln, s:jmpchr] = [pos, [chr, pos]]
		elsei exists('s:jmpchr') && s:jmpchr[0] == chr
			" Start of lines
			if s:jmpchr[1] == -1 | let s:jmpchr[1] = pos | en
			let npos = match(lines, smartcs.'^'.chr, s:jmpchr[1] + 1)
			let [jmpln, s:jmpchr] = [npos == -1 ? pos : npos, [chr, npos]]
		en
		exe 'keepj norm!' ( jmpln + 1 ).'G'
		let wincrstate = s:GetWinCursorState()
		cal s:OnUpdatedState(0, 0)
		cal s:OnPrtCursorMoved()
		cal s:SetWinCursorState(wincrstate)
	en
endf
" Misc {{{2
fu! s:PrtFocusMap(char)
	cal call(( s:focus ? 's:PrtAdd' : 's:PrtSelectJump' ), [a:char])
endf

fu! s:PrtClearCache()
	let ct = s:curtype()
	if ct == 'fil'
		cal ctrlp#clr()
	elsei s:itemtype >= len(s:coretypes)
		cal ctrlp#clr(s:statypes[s:itemtype][1])
	en
	if ct == 'mru'
		let g:ctrlp_lines = ctrlp#mrufiles#refresh()
	el
		cal ctrlp#setlines()
	en
	let s:force = 1
	cal s:OnUpdatedState(0, 1)
	unl s:force
endf

fu! s:PrtDeleteEnt()
	let ct = s:curtype()
	if ct == 'mru'
		cal s:PrtDeleteMRU()
	elsei ct == 'buf'
		cal s:delbuf()
	elsei type(s:getextvar('wipe')) == 1
		cal s:delent(s:getextvar('wipe'))
	en
endf

fu! s:PrtDeleteMRU()
	if s:curtype() == 'mru'
		cal s:delent('ctrlp#mrufiles#remove')
	en
endf

fu! s:PrtExit()
	let bw = bufwinnr('%')
	exe bufwinnr(s:bufnr).'winc w'
	if bufnr('%') == s:bufnr && bufname('%') == 'ControlP'
		noa cal s:Close()
		noa winc p
	els
		exe bw.'winc w'
	en
endf

fu! s:PrtHistory(...)
	if !s:focus || !s:maxhst | retu | en
	let [str, hst, s:matches] = [join(s:prompt, ''), s:hstry, 1]
	" Save to history if not saved before
	let [hst[0], hslen] = [exists('s:hstgot') ? hst[0] : str, len(hst)]
	let idx = exists('s:hisidx') ? s:hisidx + a:1 : a:1
	" Limit idx within 0 and hslen
	let idx = idx < 0 ? 0 : idx >= hslen ? hslen > 1 ? hslen - 1 : 0 : idx
	let s:prompt = [hst[idx], '', '']
	let [s:hisidx, s:hstgot, s:force] = [idx, 1, 1]
	cal s:OnUpdatedState(0, 1)
	unl s:force
endf
"}}}1
" * Mappings {{{1
fu! s:MapNorms()
	if exists('s:nmapped') && s:nmapped == s:bufnr | retu | en
	let pcmd = "nn \<buffer> \<silent> \<k%s> :\<c-u>cal \<SID>%s(\"%s\")\<cr>"
	let cmd = substitute(pcmd, 'k%s', 'char-%d', '')
	let pfunc = 'PrtFocusMap'
	let ranges = [32, 33, 125, 126] + range(35, 91) + range(93, 123)
	for each in [34, 92, 124]
		exe printf(cmd, each, pfunc, escape(nr2char(each), '"|\'))
	endfo
	for each in ranges
		exe printf(cmd, each, pfunc, nr2char(each))
	endfo
	for each in range(0, 9)
		exe printf(pcmd, each, pfunc, each)
	endfo
	for [ke, va] in items(s:kprange)
		exe printf(pcmd, ke, pfunc, va)
	endfo
	let s:nmapped = s:bufnr
endf

fu! s:MapSpecs()
	if !( exists('s:smapped') && s:smapped == s:bufnr )
		" Correct arrow keys in terminal
		if ( has('termresponse') && v:termresponse =~ "\<ESC>" )
			\ || &term =~? '\vxterm|<k?vt|gnome|screen|linux|ansi|tmux|st(-[-a-z0-9]*)?$'
			for each in ['\A <up>','\B <down>','\C <right>','\D <left>']
				exe s:lcmap.' <esc>['.each
			endfo
		en
	en
	for [ke, va] in items(s:prtmaps) | for kp in va
		exe s:lcmap kp ':<c-u>cal <SID>'.ke.'<cr>'
	endfo | endfo
	let s:smapped = s:bufnr
endf

fu! s:KeyLoop()
	let [t_ve, guicursor] = [&t_ve, &guicursor]
	wh exists('s:init') && s:keyloop
		try
			set t_ve=
			if guicursor != ''
				set guicursor=a:NONE
			en
			let nr = getchar()
		fina
			let &t_ve = t_ve
			let &guicursor = guicursor
		endt
		let chr = !type(nr) ? nr2char(nr) : nr
		if nr >=# 0x20
			cal s:PrtFocusMap(chr)
		el
			let cmd = matchstr(maparg(chr), ':<C-U>\zs.\+\ze<CR>$')
			try
				exe ( cmd != '' ? cmd : 'norm '.chr )
			cat
			endt
		en
	endw
endf
" * Toggling {{{1
fu! s:ToggleFocus()
	let s:focus = !s:focus
	cal s:OnUpdatedState(1, 0)
endf

fu! s:ToggleRegex()
	let s:regexp = !s:regexp
	cal s:PrtSwitcher()
endf

fu! s:ToggleByFname()
	if s:ispath
		let s:byfname = !s:byfname
		let s:mfunc = s:mfunc()
		cal s:PrtSwitcher()
	en
endf

fu! s:ToggleType(dir)
	let max = len(g:ctrlp_ext_vars) + len(s:coretypes) - 1
	let next = s:walker(max, s:itemtype, a:dir)
	cal ctrlp#setlines(next)
	cal ctrlp#syntax()
	cal s:PrtSwitcher()
endf

fu! s:ToggleKeyLoop()
	let s:keyloop = !s:keyloop
	if exists('+imd')
		let &imd = !s:keyloop
	en
	if s:keyloop
		let [&ut, s:lazy] = [0, 0]
		cal s:KeyLoop()
	elsei has_key(s:glbs, 'ut')
		let [&ut, s:lazy] = [s:glbs['ut'], 1]
	en
endf

fu! s:ToggleMRURelative()
	cal ctrlp#mrufiles#tgrel()
	cal s:PrtClearCache()
	cal s:OnUpdatedState(1, 0) " TODO: check this is needed
endf

fu! s:PrtSwitcher()
	let [s:force, s:matches] = [1, 1]
	cal s:OnUpdatedState(1, 1)
	unl s:force
endf
" - SetWD() {{{1
fu! s:SetWD(args)
	if has_key(a:args, 'args') && stridx(a:args['args'], '--dir') >= 0
		\ && exists('s:dyncwd')
		cal ctrlp#setdir(s:dyncwd) | retu
	en
	if has_key(a:args, 'dir') && a:args['dir'] != ''
		cal ctrlp#setdir(a:args['dir']) | retu
	en
	let pmodes = has_key(a:args, 'mode') ? a:args['mode'] : s:pathmode
	" MAYBE: refactor this assignment in a function (and make it use something
	" related to s:curtype()?), as 's:crfilerel' is used in 's:MatchedItems()'
	" to calculate the file (expression in 'items'/'g:ctrlp_lines') to be
	" excluded.
	"  TODO: remove code in 's:MatchedItems()' and have the "special case" for
	"  'buf' just in the function to be created from the line below.
	" XREF: search for other lines matching the following one (currently: 1 other)
	let [s:crfilerel, s:dyncwd] = [fnamemodify(s:crfile, ':.'), getcwd()]
	if (!type(pmodes))
		let pmodes =
			\ pmodes == 0 ? '' :
			\ pmodes == 1 ? 'a' :
			\ pmodes == 2 ? 'r' :
			\ 'c'
	en
	let spath = pmodes =~ 'd' ? s:dyncwd : pmodes =~ 'w' ? s:cwd : s:crfpath
	for pmode in split(pmodes, '\zs')
		if ctrlp#setpathmode(pmode, spath) | retu | en
	endfo
endf
" * AcceptSelection() {{{1
fu! ctrlp#acceptfile(...)
	let useb = 0
	if a:0 == 1 && type(a:1) == 4
		let [md, line] = [a:1['action'], a:1['line']]
		let atl = has_key(a:1, 'tail') ? a:1['tail'] : ''
	el
		let [md, line] = [a:1, a:2]
		let atl = a:0 > 2 ? a:3 : ''
	en
	if !type(line)
		let [filpath, bufnr, useb] = [line, line, 1]
	el
		let [bufnr, filpath] = s:bufnrfilpath(line)
		if bufnr == filpath
			let useb = 1
		en
	en
	cal s:PrtExit()
	let tail = s:tail()
	let j2l = atl != '' ? atl : matchstr(tail, '^ +\zs\d\+$')
	if bufnr > 0 && ( !empty(s:jmptobuf) && s:jmptobuf =~ md )
		\ && !( md == 'e' && bufnr == bufnr('%') )
		let [jmpb, bufwinnr] = [1, bufwinnr(bufnr)]
		let buftab = ( s:jmptobuf =~# '[tTVH]' || s:jmptobuf > 1 )
			\ ? s:buftab(bufnr, md) : [0, 0]
	en
	" Switch to existing buffer or open new one
	if exists('jmpb') && bufwinnr > 0
		\ && !( md == 't' && ( s:jmptobuf !~# toupper(md) || buftab[0] ) )
		exe bufwinnr.'winc w'
		if j2l | cal ctrlp#j2l(j2l) | en
	elsei exists('jmpb') && buftab[0]
		\ && !( md =~ '[evh]' && s:jmptobuf !~# toupper(md) )
		exe 'tabn' buftab[0]
		exe buftab[1].'winc w'
		if j2l | cal ctrlp#j2l(j2l) | en
	el
		" Determine the command to use
		let useb = bufnr > 0 && buflisted(bufnr) && ( empty(tail) || useb )
		let cmd =
			\ md == 't' || s:splitwin == 1 ? ( useb ? 'tab sb' : 'tabe' ) :
			\ md == 'h' || s:splitwin == 2 ? ( useb ? 'sb' : 'new' ) :
			\ md == 'v' || s:splitwin == 3 ? ( useb ? 'vert sb' : 'vne' ) :
			\ &bt == 'help' && useb ? call('ctrlp#normcmd', ['b', 'bo vert sb']) :
			\ call('ctrlp#normcmd', useb ? ['b', 'bo vert sb'] : ['e'])
		" Reset &switchbuf option
		let [swb, &swb] = [&swb, '']
		" Open new window/buffer
		let [fid, tail] = [( useb ? bufnr : filpath ), ( atl != '' ? ' +'.atl : tail )]
		let args = [cmd, fid, tail, 1, [useb, j2l]]
		cal call('s:openfile', args)
		let &swb = swb
	en
endf

fu! s:SpecInputs(str)
	if a:str =~ '\v^(\.\.([\/]\.\.)*[\/]?[.\/]*)$' && s:spi
		let cwd = s:dyncwd
		cal ctrlp#setdir(a:str =~ '^\.\.\.*$' ?
			\ '../'.repeat('../', strlen(a:str) - 2) : a:str)
		if cwd != s:dyncwd | cal ctrlp#setlines() | en
		cal s:PrtClear()
		retu 1
	elsei a:str == s:lash && s:spi
		cal s:SetWD({ 'mode': 'rd' })
		cal ctrlp#setlines()
		cal s:PrtClear()
		retu 1
	elsei a:str =~ '^@.\+' && s:spi
		retu s:at(a:str)
	elsei a:str == '?'
		cal s:PrtExit()
		let hlpwin = &columns > 159 ? '| vert res 80' : ''
		sil! exe 'bo vert h ctrlp-mappings' hlpwin '| norm! 0'
		retu 1
	en
	retu 0
endf

fu! s:AcceptSelection(action)
	let [md, icr] = [a:action[0], match(a:action, 'r') >= 0]
	let subm = icr || ( !icr && md == 'e' )
	if !subm && s:OpenMulti(md) != -1 | retu | en
	let str = s:getinput()
	if subm | if s:SpecInputs(str) | retu | en | en
	" Get the selected line
	let line = ctrlp#getcline()
	if !subm && s:curtype() != 'fil' && line == '' && line('.') > s:offset
		\ && str !~ '\v^(\.\.([\/]\.\.)*[\/]?[.\/]*|/|\\|\?|\@.+)$'
		cal s:CreateNewFile(md) | retu
	en
	if empty(line) | retu | en
	" Do something with it
	if s:openfunc != {} && has_key(s:openfunc, s:ctype)
		let actfunc = s:openfunc[s:ctype]
		let type = has_key(s:openfunc, 'arg_type') ? s:openfunc['arg_type'] : 'list'
	el
		if s:itemtype < len(s:coretypes)
			let [actfunc, type] = ['ctrlp#acceptfile', 'dict']
		el
			let [actfunc, exttype] = [s:getextvar('accept'), s:getextvar('act_farg')]
			let type = exttype == 'dict' ? exttype : 'list'
		en
	en
	" TODO: remove: echomsg 'DEBUG: s:AcceptSelection(): ' . string({ 'type': type, 'md': md, 'line': line, 'icr': icr, 'str': str })
	" orig: let actargs = (type == 'dict' ? [{ 'action': md, 'line': line, 'icr': icr, 'input': str}]
	" orig: 	\ : [md, line])
	"+ if type == 'dict'
	"+ 	let actargs = [{ 'action': md, 'line': line, 'icr': icr, 'input': str}]
	"+ else
	"+ 	let actargs = [md, line]
	"+ endif
	"- note: still get_tv_string_buf() on vim-7.0 and vim-7.1:
	"-  let actargs = ( (type == 'dict') ? ( [{ 'action': md, 'line': line, 'icr': icr, 'input': str}] ) : ( [md, line] ) )
	"
	" NOTE: this fixes vim-7.0 and vim-7.1, which choked on this
	" command/sentence:
	"		let actargs = type == 'dict' ? [{ 'action': md, 'line': line, 'icr': icr, 'input': str}]
	"		 \ : [md, line]
	if type == 'dict'
		let actargs = [{ 'action': md, 'line': line, 'icr': icr, 'input': str}]
	el
		let actargs = [md, line]
	en
	cal call(actfunc, actargs)
endf
" - CreateNewFile() {{{1
fu! s:CreateNewFile(...)
	let [md, str] = ['', s:getinput('n')]
	if empty(str) | retu | en
	if s:argmap && !a:0
		" Get the extra argument
		let md = s:argmaps(md, 1)
		if md == 'cancel' | retu | en
	en
	let str = s:sanstail(str)
	let [base, fname] = s:headntail(str)
	if fname =~ '^[\/]$' | retu | en
	if exists('s:marked') && len(s:marked)
		" Use the first marked file's path
		let path = fnamemodify(values(s:marked)[0], ':p:h')
		let base = path.s:lash(path).base
		let str = fnamemodify(base.s:lash.fname, ':.')
	en
	if base != '' | if isdirectory(ctrlp#utils#mkdir(base))
		let optyp = str | en | el | let optyp = fname
	en
	if !exists('optyp') | retu | en
	let [filpath, tail] = [fnamemodify(optyp, ':p'), s:tail()]
	if !stridx(filpath, s:dyncwd) | cal s:insertcache(str) | en
	cal s:PrtExit()
	let cmd = md == 'r' ? ctrlp#normcmd('e') :
		\ s:newfop =~ '1\|t' || ( a:0 && a:1 == 't' ) || md == 't' ? 'tabe' :
		\ s:newfop =~ '2\|h' || ( a:0 && a:1 == 'h' ) || md == 'h' ? 'new' :
		\ s:newfop =~ '3\|v' || ( a:0 && a:1 == 'v' ) || md == 'v' ? 'vne' :
		\ ctrlp#normcmd('e')
	cal s:openfile(cmd, filpath, tail, 1)
endf
" * OpenMulti() {{{1
fu! s:MarkToOpen()
	let ct = s:curtype()
	if s:bufnr <= 0 || s:opmul == '0'
		\ || ( s:itemtype >= len(s:coretypes) && s:getextvar('opmul') != 1 )
		retu
	en
	let line = ctrlp#getcline()

	" Do not allow to mark modified or current buffer
	let bufnr = s:bufnrfilpath(line)[0]
	if (ct == 'buf' && s:delbufcond(bufnr))
		retu
	en

	if empty(line) | retu | en
	let filpath = s:ispath ? fnamemodify(line, ':p') : line
	if exists('s:marked') && s:dictindex(s:marked, filpath) > 0
		" Unmark and remove the file from s:marked
		let key = s:dictindex(s:marked, filpath)
		cal remove(s:marked, key)
		if empty(s:marked) | unl s:marked | en
		if has('signs')
			exe 'sign unplace' key 'buffer='.s:bufnr
		en
	el
		" Add to s:marked and place a new sign
		if exists('s:marked')
			let vac = s:vacantdict(s:marked)
			let key = empty(vac) ? len(s:marked) + 1 : vac[0]
			let s:marked = extend(s:marked, { key : filpath })
		el
			let [key, s:marked] = [1, { 1 : filpath }]
		en
		if has('signs')
			exe 'sign place' key 'line='.line('.').' name=ctrlpmark buffer='.s:bufnr
		en
	en
	sil! cal ctrlp#statusline()
endf

fu! s:OpenMulti(...)
	let has_marked = exists('s:marked')
	if ( !has_marked && a:0 ) || s:opmul == '0' || !s:ispath
		\ || ( s:itemtype >= len(s:coretypes) && s:getextvar('opmul') != 1 )
		retu -1
	en
	" Get the options
	let [nr, md] = [matchstr(s:opmul, '\d\+'), matchstr(s:opmul, '[thvi]')]
	let [ur, jf] = [s:opmul =~ 'r', s:opmul =~ 'j']
	let md = a:0 ? a:1 : ( md == '' ? 'v' : md )
	let nopt = exists('g:ctrlp_open_multiple_files')
	if !has_marked
		let line = ctrlp#getcline()
		if line == '' | retu | en
		let marked = { 1 : fnamemodify(line, ':p') }
		let [nr, ur, jf, nopt] = ['1', 0, 0, 1]
	en
	if ( s:argmap || !has_marked ) && !a:0
		let md = s:argmaps(md, !has_marked ? 2 : 0)
		if md == 'c'
			cal s:unmarksigns()
			unl! s:marked
			cal s:OnUpdatedState(1, 0)
		elsei !has_marked && md =~ '[axd]'
			retu s:OpenNoMarks(md, line)
		en
		if md =~ '\v^c(ancel)?$' | retu | en
		let nr = nr == '0' ? ( nopt ? '' : '1' ) : nr
		let ur = !has_marked && md == 'r' ? 1 : ur
	en
	let mkd = values(has_marked ? s:marked : marked)
	cal s:sanstail(join(s:prompt, ''))
	cal s:PrtExit()
	if nr == '0' || md == 'i'
		retu map(mkd, "s:openfile('bad', v:val, '', 0)")
	en
	let tail = s:tail()
	let [emptytail, bufnr] = [empty(tail), bufnr('^'.mkd[0].'$')]
	let useb = bufnr > 0 && buflisted(bufnr) && emptytail
	" Move to a replaceable window
	let ncmd = ( useb ? ['b', 'bo vert sb'] : ['e', 'bo vne'] )
		\ + ( ur ? [] : ['ignruw'] )
	let fst = call('ctrlp#normcmd', ncmd)
	" Check if the current window has a replaceable buffer
	let repabl = !( md == 't' && !ur ) && empty(bufname('%')) && empty(&l:ft)
	" Commands for the rest of the files
	let [ic, cmds] = [1, { 'v': ['vert sb', 'vne'], 'h': ['sb', 'new'],
		\ 't': ['tab sb', 'tabe'] }]
	let [swb, &swb] = [&swb, '']
	if md == 't' && ctrlp#tabcount() < tabpagenr()
		let s:tabct = ctrlp#tabcount()
	en
	" Open the files
	for va in mkd
		let bufnr = bufnr('^'.va.'$')
		if bufnr < 0 && getftype(va) == '' | con | en
		let useb = bufnr > 0 && buflisted(bufnr) && emptytail
		let snd = md != '' && has_key(cmds, md) ?
			\ ( useb ? cmds[md][0] : cmds[md][1] ) : ( useb ? 'vert sb' : 'vne' )
		let cmd = ic == 1 && ( !( !ur && fst =~ '^[eb]$' ) || repabl ) ? fst : snd
		let conds = [( nr != '' && nr > 1 && nr < ic ) || ( nr == '' && ic > 1 ),
			\ nr != '' && nr < ic]
		if conds[nopt]
			if !buflisted(bufnr) | cal s:openfile('bad', va, '', 0) | en
		el
			cal s:openfile(cmd, useb ? bufnr : va, tail, ic == 1)
			if jf | if ic == 1
				let crpos = [tabpagenr(), winnr()]
			el
				let crpos[0] += tabpagenr() <= crpos[0]
				let crpos[1] += winnr() <= crpos[1]
			en | en
			let ic += 1
		en
	endfo
	if jf && exists('crpos') && ic > 2
		exe ( md == 't' ? 'tabn '.crpos[0] : crpos[1].'winc w' )
	en
	let &swb = swb
	unl! s:tabct
endf

fu! s:YankLine(...)
	let @" = s:getinput()
	let has_marked = exists('s:marked')
	if !has_marked
		let line = ctrlp#getcline()
		if line == '' | retu | en
		let marked = { 1 : fnamemodify(line, ':p') }
	en
	let @" = join(values(has_marked ? s:marked : marked), "\n")
	cal s:PrtExit()
endf

fu! s:OpenNoMarks(md, line)
	if a:md == 'a'
		let [s:marked, key] = [{}, 1]
		for line in s:lines
			let s:marked = extend(s:marked, { key : fnamemodify(line, ':p') })
			let key += 1
		endfo
		cal s:remarksigns()
		cal s:OnUpdatedState(1, 0)
	elsei a:md == 'x'
		let type = has_key(s:openfunc, 'arg_type') ? s:openfunc['arg_type'] : 'dict'
		let argms = type == 'dict' ? [{ 'action': a:md, 'line': a:line }]
			\ : [a:md, a:line]
		cal call(s:openfunc[s:ctype], argms, s:openfunc)
	elsei a:md == 'd'
		let dir = fnamemodify(a:line, ':h')
		if isdirectory(dir)
			cal ctrlp#setdir(dir)
			cal ctrlp#switchtype(0)
			cal ctrlp#recordhist()
			cal s:PrtClear()
		en
	en
endf
" ** Helper functions {{{1
" Sorting {{{2
fu! ctrlp#complen(...)
	" By length
	let [len1, len2] = [strlen(a:1), strlen(a:2)]
	retu len1 == len2 ? 0 : len1 > len2 ? 1 : -1
endf

fu! s:compmatlen(...)
	" By match length
	let mln1 = s:shortest(s:matchlens(a:1, s:compat))
	let mln2 = s:shortest(s:matchlens(a:2, s:compat))
	retu mln1 == mln2 ? 0 : mln1 > mln2 ? 1 : -1
endf

fu! s:comptime(...)
	" By last modified time
	let [time1, time2] = [getftime(a:1), getftime(a:2)]
	retu time1 == time2 ? 0 : time1 < time2 ? 1 : -1
endf

fu! s:comp_subtracttosortret(subtraction_result)
	retu
				\	(a:subtraction_result > 0) ? 1 :
				\	(a:subtraction_result < 0) ? -1 :
				\	0
endf

" NOTE: this function gives a more consistent output (uses the bufnr value
" itself as a tie breaker).
fu! s:compmreb(...)
	let [bufnr1, bufnr2] = [a:1, a:2]
	" By last entered time (bufnr)
	let [id1, id2] = [index(s:mrbs, bufnr1), index(s:mrbs, bufnr2)]
	" MAYBE: reorder to prioritise the "successful" case (both id1, id2 >= 0)
	" MAYBE: IDEA: something "clever" to minimise comparisons:
	"? (v1): "  (first case: caters for bufnr1 == bufnr2, and also for id1 == id2 == -1)
	"? (v1): "  (second case: only one of id1, id2 is < 0)
	"? (v1): retu
	"? (v1): 			\	(id1 == id2) ? s:comp_subtracttosortret(bufnr1 - bufnr2) :
	"? (v1): 			\	(min([id1, id2]) < 0) ? s:comp_subtracttosortret(id2 - id1) :
	"? (v1): 			\	s:comp_subtracttosortret(id1 - id2)
	"? (v2): retu
	"? (v2): 			\	(min([id1, id2]) >= 0) ? s:comp_subtracttosortret(id1 - id2) :
	"? (v2): 			\	(id1 == id2) ? s:comp_subtracttosortret(bufnr1 - bufnr2) :
	"? (v2): 			\	s:comp_subtracttosortret(id2 - id1)
	retu
				\	((id1 < 0) && (id2 < 0)) ? s:comp_subtracttosortret(bufnr1 - bufnr2) :
				\	(id2 < 0) ? -1 :
				\	(id1 < 0) ? 1 :
				\	s:comp_subtracttosortret(id1 - id2)
endf

fu! s:compmref(...)
	" By last entered time (MRU)
	let [id1, id2] = [index(g:ctrlp_lines, a:1), index(g:ctrlp_lines, a:2)]
	retu id1 == id2 ? 0 : id1 > id2 ? 1 : -1
endf

fu! s:comparent(...)
	" By same parent dir
	if !stridx(s:crfpath, s:dyncwd)
		let [as1, as2] = [s:dyncwd.s:lash().a:1, s:dyncwd.s:lash().a:2]
		let [loc1, loc2] = [s:getparent(as1), s:getparent(as2)]
		if loc1 == s:crfpath && loc2 != s:crfpath | retu -1 | en
		if loc2 == s:crfpath && loc1 != s:crfpath | retu 1  | en
		retu 0
	en
	retu 0
endf

fu! s:compfnlen(...)
	" By filename length
	let len1 = strlen(split(a:1, s:lash)[-1])
	let len2 = strlen(split(a:2, s:lash)[-1])
	retu len1 == len2 ? 0 : len1 > len2 ? 1 : -1
endf

fu! s:matchlens(str, pat, ...)
	if empty(a:pat) || index(['^', '$'], a:pat) >= 0 | retu {} | en
	let st   = a:0 ? a:1 : 0
	let lens = a:0 >= 2 ? a:2 : {}
	let nr   = a:0 >= 3 ? a:3 : 0
	if nr > 20 | retu {} | en
	if match(a:str, a:pat, st) >= 0
		let [mst, mnd] = [matchstr(a:str, a:pat, st), matchend(a:str, a:pat, st)]
		let lens = extend(lens, { nr : [strlen(mst), mst] })
		let lens = s:matchlens(a:str, a:pat, mnd, lens, nr + 1)
	en
	retu lens
endf

fu! s:shortest(lens)
	retu min(map(values(a:lens), 'v:val[0]'))
endf

fu! s:mixedsort(...)
	let ct = s:curtype()
	if ct == 'buf'
		let pat = '[\/]\?\[\d\+\*No Name\]$'
		if a:1 =~# pat && a:2 =~# pat | retu 0
		elsei a:1 =~# pat | retu 1
		elsei a:2 =~# pat | retu -1 | en
	en
	let [cln, cml] = [ctrlp#complen(a:1, a:2), s:compmatlen(a:1, a:2)]
	if s:ispath
		let ms = []
		if s:res_count < 21
			let ms += [s:compfnlen(a:1, a:2)]
			if ct !~ '^\(buf\|mru\)$' | let ms += [s:comptime(a:1, a:2)] | en
			if !s:itemtype | let ms += [s:comparent(a:1, a:2)] | en
		en
		if ct =~ '^\(buf\|mru\)$'
			let ms += [s:compmref(a:1, a:2)]
			let cln = cml ? cln : 0
		en
		let ms += [cml, 0, 0, 0]
		let mp = call('s:multipliers', ms[:3])
		retu cln + ms[0] * mp[0] + ms[1] * mp[1] + ms[2] * mp[2] + ms[3] * mp[3]
	en
	retu cln + cml * 2
endf

fu! s:multipliers(...)
	let mp0 = !a:1 ? 0 : 2
	let mp1 = !a:2 ? 0 : 1 + ( !mp0 ? 1 : mp0 )
	let mp2 = !a:3 ? 0 : 1 + ( !( mp0 + mp1 ) ? 1 : ( mp0 + mp1 ) )
	let mp3 = !a:4 ? 0 : 1 + ( !( mp0 + mp1 + mp2 ) ? 1 : ( mp0 + mp1 + mp2 ) )
	retu [mp0, mp1, mp2, mp3]
endf

fu! s:compval(...)
	retu a:1 - a:2
endf
" Statusline {{{2
fu! ctrlp#statusline()
	if !exists('s:statypes')
		let s:statypes = copy(s:coretypes)
		if !empty(g:ctrlp_ext_vars)
			cal map(copy(g:ctrlp_ext_vars),
				\ 'add(s:statypes, [ v:val["lname"], v:val["sname"] ])')
		en
	en
	let tps = s:statypes
	let max = len(tps) - 1
	let nxt = tps[s:walker(max, s:itemtype,  1)][1]
	let prv = tps[s:walker(max, s:itemtype, -1)][1]
	let s:ctype = tps[s:itemtype][0]
	let focus   = s:focus ? 'prt'  : 'win'
	let byfname = s:ispath ? s:byfname ? 'file' : 'path' : 'line'
	let marked  = s:opmul != '0' ?
		\ exists('s:marked') ? ' <'.s:dismrk().'>' : ' <->' : ''
	if s:status != {}
		" FIXME: remove
		cal ctrlp#ev_log_printf('ctlrp: about to use custom status bar')
		let argms =
			\ has_key(s:status, 'arg_type') && s:status['arg_type'] == 'dict' ? [{
			\ 'focus':   focus,
			\ 'byfname': byfname,
			\ 'regex':   s:regexp,
			\ 'prev':    prv,
			\ 'item':    s:ctype,
			\ 'next':    nxt,
			\ 'marked':  marked,
			\ }] : [focus, byfname, s:regexp, prv, s:ctype, nxt, marked]
		let &l:stl = call(s:status['main'], argms, s:status)
	el
		" FIXME: remove
		cal ctrlp#ev_log_printf('ctlrp: about to use own status bar')
		let item    = '%#CtrlPMode1# '.s:ctype.' %*'
		let focus   = '%#CtrlPMode2# '.focus.' %*'
		let byfname = '%#CtrlPMode1# '.byfname.' %*'
		let regex   = s:regexp  ? '%#CtrlPMode2# regex %*' : ''
		let slider  = ' <'.prv.'>={'.item.'}=<'.nxt.'>'
		let dir     = ' %=%<%#CtrlPMode2# %{getcwd()} %*'
		" TODO: remove: same?: cal setwinvar(winnr(), '&stl', focus.byfname.regex.slider.marked.dir)
		" TODO: remove: still does not work: setlocal statusline=this_is_ctrlp_s_internal_statusline
		let &l:stl  = focus.byfname.regex.slider.marked.dir
	en
	cal ctrlp#ev_log_printf('ctlrp: statusline: %s', string(&l:stl))
endf

fu! s:dismrk()
	retu has('signs') ? len(s:marked) :
		\ '%<'.join(values(map(copy(s:marked), 'split(v:val, "[\\/]")[-1]')), ', ')
endf

fu! ctrlp#progress(enum, ...)
	if has('macunix') || has('mac') | sl 1m | en
	let txt = a:0 ? '(press ctrl-c to abort)' : ''
	if s:status != {}
		let argms = has_key(s:status, 'arg_type') && s:status['arg_type'] == 'dict'
			\ ? [{ 'str': a:enum }] : [a:enum]
		let &l:stl = call(s:status['prog'], argms, s:status)
	el
		let &l:stl = '%#CtrlPStats# '.a:enum.' %* '.txt.'%=%<%#CtrlPMode2# %{getcwd()} %*'
	en
	redraws
endf
" *** Paths {{{2
" Line formatting {{{3
fu! s:formatline(str)
	let str = a:str
	let ct = s:curtype()
	if ct == 'buf'
		let bufnr = s:bufnrfilpath(str)[0]
		let parts = s:bufparts(bufnr)
		let str = printf('%'.s:bufnr_width.'s', bufnr)
		if s:has_conceal && has('syntax_items')
			let str .= printf(' %-13s %s%-36s',
				\ '<bi>'.parts[0].'</bi>',
				\ '<bn>'.parts[1], '{'.parts[2].'}</bn>')
			let str .= printf('  %s', '<bp>'.s:getpathamefrombufparts(parts).'</bp>')
		el
			let str .= printf(' %-5s %-30s',
				\ parts[0],
				\ parts[2])
			let str .= printf('  %s', s:getpathamefrombufparts(parts))
		en
	en
	let cond = ct != 'buf' &&s:ispath && ( s:winw - 4 ) < s:strwidth(str)
	retu s:lineprefix.( cond ? s:pathshorten(str) : str )
endf

fu! s:pathshorten(str)
	retu matchstr(a:str, '^.\{9}').'...'
		\ .matchstr(a:str, '.\{'.( s:winw - 16 ).'}$')
endf

fu! s:offset(lines, height)
	let s:offset = s:mw_order == 'btt' ? ( a:height - s:res_count ) : 0
	retu s:offset > 0 ? ( repeat([''], s:offset) + a:lines ) : a:lines
endf
" Directory completion {{{3
fu! s:dircompl(be, sd)
	if a:sd == '' | retu [] | en
	if a:be == ''
		let [be, sd] = [s:dyncwd, a:sd]
	el
		let be = a:be.s:lash(a:be)
		let sd = be.a:sd
	en
	let dirs = split(globpath(s:fnesc(be, 'g', ','), a:sd.'*/'), "\n")
	if a:be == ''
		let dirs = ctrlp#rmbasedir(dirs)
	en
	cal filter(dirs, '!match(v:val, escape(sd, ''~$.\''))'
		\ . ' && v:val !~ ''\v(^|[\/])\.{1,2}[\/]$''')
	retu dirs
endf

fu! s:findcommon(items, seed)
	let [items, id, cmn, ic] = [copy(a:items), strlen(a:seed), '', 0]
	cal map(items, 'strpart(v:val, id)')
	for char in split(items[0], '\zs')
		for item in items[1:]
			if item[ic] != char | let brk = 1 | brea | en
		endfo
		if exists('brk') | brea | en
		let cmn .= char
		let ic += 1
	endfo
	retu cmn
endf
" Misc {{{3
fu! s:headntail(str)
	let parts = split(a:str, '[\/]\ze[^\/]\+[\/:]\?$')
	retu len(parts) == 1 ? ['', parts[0]] : len(parts) == 2 ? parts : []
endf

fu! s:lash(...)
	retu ( a:0 ? a:1 : s:dyncwd ) !~ '[\/]$' ? s:lash : ''
endf

fu! s:ispathitem()
	retu s:itemtype < len(s:coretypes) || s:getextvar('type') == 'path'
endf

fu! ctrlp#igncwd(cwd)
	retu ctrlp#utils#glob(a:cwd, 0) == '' ||
		\ ( s:igntype >= 0 && s:usrign(a:cwd, getftype(a:cwd)) )
endf

fu! ctrlp#dirnfile(entries)
	let [items, cwd] = [[[], []], s:dyncwd.s:lash()]
	for each in a:entries
		let etype = getftype(each)
		if s:igntype >= 0 && s:usrign(each, etype) | con | en
		if etype == 'dir'
			if s:showhidden | if each !~ '[\/]\.\{1,2}$'
				cal add(items[0], each)
			en | el
				cal add(items[0], each)
			en
		elsei etype == 'link'
			if s:folsym
				let isfile = !isdirectory(each)
				if s:folsym == 2 || !s:samerootsyml(each, isfile, cwd)
					cal add(items[isfile], each)
				en
			en
		elsei etype == 'file'
			cal add(items[1], each)
		en
	endfo
	retu items
endf

fu! s:usrign(item, type)
	if s:igntype == 1 | retu a:item =~ s:usrign | en
	if s:igntype == 2
		if call(s:usrign, [a:item, a:type])
			retu 1
		en
	elsei s:igntype == 4
		if has_key(s:usrign, a:type) && s:usrign[a:type] != ''
					\ && a:item =~ s:usrign[a:type]
			retu 1
		elsei has_key(s:usrign, 'func') && s:usrign['func'] != ''
					\ && call(s:usrign['func'], [a:item, a:type])
			retu 1
		en
	en
	retu 0
endf

fu! s:samerootsyml(each, isfile, cwd)
	let resolve = fnamemodify(resolve(a:each), ':p:h')
	let resolve .= s:lash(resolve)
	retu !( stridx(resolve, a:cwd) && ( stridx(a:cwd, resolve) || a:isfile ) )
endf

fu! ctrlp#rmbasedir(items)
	if a:items == []
		retu a:items
	en
	let cwd = s:dyncwd.s:lash()
	let first = a:items[0]
	if has('win32') || has('win64')
		let cwd = tr(cwd, '\', '/')
		let first = tr(first, '\', '/')
	en
	if !stridx(first, cwd)
		let idx = strlen(cwd)
		retu map(a:items, 'strpart(v:val, idx)')
	en
	retu a:items
endf
" Working directory {{{3
fu! s:getparent(item)
	let parent = substitute(a:item, '[\/][^\/]\+[\/:]\?$', '', '')
	if parent == '' || parent !~ '[\/]'
		let parent .= s:lash
	en
	retu parent
endf

fu! s:findroot(curr, mark, depth, type)
	let [depth, fnd] = [a:depth + 1, 0]
	if type(a:mark) == 1
		let fnd = s:glbpath(s:fnesc(a:curr, 'g', ','), a:mark, 1) != ''
	elsei type(a:mark) == 3
		for markr in a:mark
			if s:glbpath(s:fnesc(a:curr, 'g', ','), markr, 1) != ''
				let fnd = 1
				brea
			en
		endfo
	en
	if fnd
		if !a:type | cal ctrlp#setdir(a:curr) | en
		"- verbose echomsg printf( 'DEBUG: s:findroot(): returning %s', string([exists('markr') ? markr : a:mark, a:curr]) )
		retu [exists('markr') ? markr : a:mark, a:curr]
	elsei depth > s:maxdepth
		cal ctrlp#setdir(s:cwd)
	el
		let parent = s:getparent(a:curr)
		if parent != a:curr
			"- verbose echomsg printf( 'DEBUG: s:findroot(): returning %s', string(s:findroot(parent, a:mark, depth, a:type)) )
			retu s:findroot(parent, a:mark, depth, a:type)
		en
	en
	"- verbose echomsg printf( 'DEBUG: s:findroot(): returning %s', string([]) )
	retu []
endf

fu! ctrlp#setpathmode(pmode, ...)
	if a:pmode == 'c' || ( a:pmode == 'a' && stridx(s:crfpath, s:cwd) < 0 )
		if exists('+acd') | let [s:glb_acd, &acd] = [&acd, 0] | en
		cal ctrlp#setdir(s:crfpath)
		retu 1
	elsei a:pmode == 'r'
		let spath = a:0 ? a:1 : s:crfpath
		let markers = ['.git', '.hg', '.svn', '.bzr', '_darcs']
		if type(s:rmarkers) == 3 && !empty(s:rmarkers)
			if s:findroot(spath, s:rmarkers, 0, 0) != [] | retu 1 | en
			cal filter(markers, 'index(s:rmarkers, v:val) < 0')
			let markers = s:rmarkers + markers
		en
		if s:findroot(spath, markers, 0, 0) != [] | retu 1 | en
	en
	retu 0
endf

fu! ctrlp#setdir(path, ...)
	let cmd = a:0 ? a:1 : 'lc!'
	sil! exe cmd s:fnesc(a:path, 'c')
	" XREF: see comments in 's:SetWD()'
	let [s:crfilerel, s:dyncwd] = [fnamemodify(s:crfile, ':.'), getcwd()]
endf
" Fallbacks {{{3
fu! s:glbpath(...)
	retu call('ctrlp#utils#globpath', a:000)
endf

fu! s:fnesc(...)
	retu call('ctrlp#utils#fnesc', a:000)
endf

fu! ctrlp#setlcdir()
	if exists('*haslocaldir')
		cal ctrlp#setdir(getcwd(), haslocaldir() ? 'lc!' : 'cd!')
	en
endf
" Highlighting {{{2
fu! ctrlp#syntax()
	if ctrlp#nosy() | retu | en
	for [ke, va] in items(s:hlgrps) | cal ctrlp#hicheck('CtrlP'.ke, va) | endfo
	let bgColor=synIDattr(synIDtrans(hlID('Normal')), 'bg')
	if bgColor !~ '^-1$\|^$'
		sil! exe 'hi CtrlPLinePre guifg='.bgColor.' ctermfg='.bgColor
	en
	sy match CtrlPNoEntries '^ == NO ENTRIES ==$'
	if hlexists('CtrlPLinePre')
		exe "sy match CtrlPLinePre '^".escape(get(g:, 'ctrlp_line_prefix', '>'),'^$.*~\')."'"
	en

	if s:curtype() == 'buf' && s:has_conceal
		" MAYBE: use the same 'escape()' value as above, and use
		" 'g:ctrlp_line_prefix' instead of the fixed '>'?
		sy region CtrlPBufferNr     matchgroup=CtrlPLinePre start='^>\s\+' end='\s'
		sy region CtrlPBufferInd    concealends matchgroup=Ignore start='<bi>' end='</bi>'
		sy region CtrlPBufferRegion concealends matchgroup=Ignore start='<bn>' end='</bn>'
			\ contains=CtrlPBufferHid,CtrlPBufferHidMod,CtrlPBufferVis,CtrlPBufferVisMod,CtrlPBufferCur,CtrlPBufferCurMod
		sy region CtrlPBufferHid    concealends matchgroup=Ignore     start='\s*{' end='}' contained
		sy region CtrlPBufferHidMod concealends matchgroup=Ignore    start='+\s*{' end='}' contained
		sy region CtrlPBufferVis    concealends matchgroup=Ignore   start='\*\s*{' end='}' contained
		sy region CtrlPBufferVisMod concealends matchgroup=Ignore  start='\*+\s*{' end='}' contained
		sy region CtrlPBufferCur    concealends matchgroup=Ignore  start='\*!\s*{' end='}' contained
		sy region CtrlPBufferCurMod concealends matchgroup=Ignore start='\*+!\s*{' end='}' contained
		sy region CtrlPBufferPath   concealends matchgroup=Ignore start='<bp>' end='</bp>'
	en
endf

fu! s:highlight(pat, grp)
	if s:matcher != {} | retu | en
	cal clearmatches()
	if !empty(a:pat) && s:ispath
		if s:regexp
			let pat = substitute(a:pat, '\\\@<!\^', '^> \\zs', 'g')
			cal matchadd(a:grp, ( s:martcs == '' ? '\c' : '\C' ).pat)
		el
			let pat = a:pat

			" get original characters so we can rebuild pat
			" TODO: consider the tab escape sequence here as well
			" MAYBE: consider every [^{stuff}] regex? or would that hit "too much"
			" (user regexes?).
			let chars = split(pat, '\[\^\\\?.\]\\{-}')

			" TODO: consider whether we will span across tabs (probably not)
			" Build a pattern like /a.*b.*c/ from abc (but with .\{-} non-greedy
			" matchers instead)
			" FIXME: only add the '\t' if the match type would merit that.
			" orig: let pat = join(chars, '.\{-}')
			"? let pat = join(chars, '[^\t]\{-}')
			let pat = join(chars, '.\{-}')
			" Ensure we match the last version of our pattern
			let ending = '\(.*'.pat.'\)\@!'
			" Case sensitive?
			let beginning = ( s:martcs == '' ? '\c' : '\C' ).'^.*'
			if s:byfname()
				" Make sure there are no slashes in our match
				let beginning = beginning.'\([^\/]*$\)\@='
			en

			for i in range(len(chars))
				" Surround our current target letter with \zs and \ze so it only
				" actually matches that one letter, but has all preceding and trailing
				" letters as well.
				" \zsa.*b.*c
				" a\(\zsb\|.*\zsb)\ze.*c
				let charcopy = copy(chars)
				if i == 0
					let charcopy[i] = '\zs'.charcopy[i].'\ze'
					let middle = join(charcopy, '.\{-}')
				el
					let before = join(charcopy[0:i-1], '.\{-}')
					let after = join(charcopy[i+1:-1], '.\{-}')
					let c = charcopy[i]
					" for abc, match either ab.\{-}c or a.*b.\{-}c in that order
					let cpat = '\(\zs'.c.'\|'.'.*\zs'.c.'\)\ze.*'
					let middle = before.cpat.after
				en

				" Now we matchadd for each letter, the basic form being:
				" ^.*\zsx\ze.*$, but with our pattern we built above for the letter,
				" and a negative lookahead ensuring that we only highlight the last
				" occurrence of our letters. We also ensure that our matcher is case
				" insensitive or sensitive depending.
				cal matchadd(a:grp, beginning.middle.ending)
			endfo
		en

		cal matchadd('CtrlPLinePre', '^>')
	elseif !empty(a:pat) && s:regexp &&
				\ exists('g:ctrlp_regex_always_higlight') &&
				\ g:ctrlp_regex_always_higlight
		let pat = substitute(a:pat, '\\\@<!\^', '^> \\zs', 'g')
		cal matchadd(a:grp, ( s:martcs == '' ? '\c' : '\C').pat)
	en
endf

fu! s:dohighlight()
	retu s:mathi[0] && exists('*clearmatches') && !ctrlp#nosy()
endf
" Prompt history {{{2
fu! s:gethistloc()
	let utilcadir = ctrlp#utils#cachedir()
	let cache_dir = utilcadir.s:lash(utilcadir).'hist'
	retu [cache_dir, cache_dir.s:lash(cache_dir).'cache.txt']
endf

fu! s:gethistdata()
	retu ctrlp#utils#readfile(s:gethistloc()[1])
endf

fu! ctrlp#recordhist()
	let str = join(s:prompt, '')
	if empty(str) || !s:maxhst | retu | en
	let hst = s:hstry
	if len(hst) > 1 && hst[1] == str | retu | en
	cal extend(hst, [str], 1)
	if len(hst) > s:maxhst | cal remove(hst, s:maxhst, -1) | en
	cal ctrlp#utils#writecache(hst, s:gethistloc()[0], s:gethistloc()[1])
endf
" Signs {{{2
fu! s:unmarksigns()
	if !s:dosigns() | retu | en
	for key in keys(s:marked)
		exe 'sign unplace' key 'buffer='.s:bufnr
	endfo
endf

fu! s:remarksigns()
	if !s:dosigns() | retu | en
	for ic in range(1, len(s:lines))
		let line = s:ispath ? fnamemodify(s:lines[ic - 1], ':p') : s:lines[ic - 1]
		let key = s:dictindex(s:marked, line)
		if key > 0
			exe 'sign place' key 'line='.ic.' name=ctrlpmark buffer='.s:bufnr
		en
	endfo
endf

fu! s:dosigns()
	retu exists('s:marked') && s:bufnr > 0 && s:opmul != '0' && has('signs')
endf
" Lists & Dictionaries {{{2
fu! s:ifilter(list, str)
	let [rlist, estr] = [[], substitute(a:str, 'v:val', 'each', 'g')]
	for each in a:list
		try
			if eval(estr)
				cal add(rlist, each)
			en
		cat | con | endt
	endfo
	retu rlist
endf

fu! s:dictindex(dict, expr)
	for key in keys(a:dict)
		if a:dict[key] ==# a:expr | retu key | en
	endfo
	retu -1
endf

fu! s:vacantdict(dict)
	retu filter(range(1, max(keys(a:dict))), '!has_key(a:dict, v:val)')
endf

fu! s:sublist(l, s, e)
	retu v:version > 701 ? a:l[(a:s):(a:e)] : s:sublist7071(a:l, a:s, a:e)
endf

fu! s:sublist7071(l, s, e)
	let [newlist, id, ae] = [[], a:s, a:e == -1 ? len(a:l) - 1 : a:e]
	wh id <= ae
		cal add(newlist, get(a:l, id))
		let id += 1
	endw
	retu newlist
endf
" Buffers {{{2
fu! s:buftab(bufnr, md)
	for tabnr in range(1, tabpagenr('$'))
		if tabpagenr() == tabnr && a:md == 't' | con | en
		let buflist = tabpagebuflist(tabnr)
		if index(buflist, a:bufnr) >= 0
			for winnr in range(1, tabpagewinnr(tabnr, '$'))
				if buflist[winnr - 1] == a:bufnr | retu [tabnr, winnr] | en
			endfo
		en
	endfo
	retu [0, 0]
endf

fu! s:bufwins(bufnr)
	let winns = 0
	for tabnr in range(1, tabpagenr('$'))
		let winns += count(tabpagebuflist(tabnr), a:bufnr)
	endfo
	retu winns
endf

fu! s:isabs(path)
	if (has('win32') || has('win64'))
		return a:path =~ '^\([a-zA-Z]:\)\{-}[/\\]'
	el
		return a:path =~ '^[/\\]'
	en
endf

fu! s:bufnrfilpath(line)
  if s:isabs(a:line) || a:line =~ '^\~[/\\]' || a:line =~ '^\w\+:\/\/'
		let filpath = a:line
	el
		let filpath = s:dyncwd.s:lash().a:line
	en
	let filpath = fnamemodify(filpath, ':p')
	let bufnr = bufnr('\V\^'.escape(filpath, '\').'\$')
	if (!filereadable(filpath) && bufnr < 1)
		if (a:line =~ '[\/]\?\[\d\+\*No Name\]$')
			let bufnr = str2nr(matchstr(a:line, '[\/]\?\[\zs\d\+\ze\*No Name\]$'))
			let filpath = bufnr
		els
			let bufnr = bufnr(a:line)
			retu [bufnr, a:line]
		en
	en
	retu [bufnr, filpath]
endf

fu! ctrlp#normcmd(cmd, ...)
	let buftypes = [ 'quickfix', 'help', 'nofile' ]
	if a:0 < 2 && s:nosplit() | retu a:cmd | en
	let norwins = filter(range(1, winnr('$')),
		\ 'index(buftypes, getbufvar(winbufnr(v:val), "&bt")) == -1 || s:isterminal(winbufnr(v:val))')
	for each in norwins
		let bufnr = winbufnr(each)
		if empty(bufname(bufnr)) && empty(getbufvar(bufnr, '&ft'))
			let fstemp = each | brea
		en
	endfo
	let norwin = empty(norwins) ? 0 : norwins[0]
	if norwin
		if index(norwins, winnr()) < 0
			exe ( exists('fstemp') ? fstemp : norwin ).'winc w'
		en
		retu a:cmd
	en
	retu a:0 ? a:1 : 'bo vne'
endf

fu! ctrlp#modfilecond(w)
	retu &mod && !&hid && &bh != 'hide' && s:bufwins(bufnr('%')) == 1 && !&cf &&
		\ ( ( !&awa && a:w ) || filewritable(fnamemodify(bufname('%'), ':p')) != 1 )
endf

fu! s:nosplit()
	retu !empty(s:nosplit) && match([bufname('%'), &l:ft, &l:bt], s:nosplit) >= 0
endf

fu! s:setupblank()
	setl noswf nonu nobl nowrap nolist nospell nocuc wfh
	setl fdc=0 fdl=99 tw=0 bt=nofile bh=unload
	if v:version > 702
		setl nornu noudf cc=0
	en
	if s:has_conceal
		setl cole=2 cocu=nc
	en
endf

fu! s:leavepre()
	if exists('s:bufnr') && s:bufnr == bufnr('%') | bw! | en
	if !( exists(s:ccex) && !{s:ccex} )
		\ && !( has('clientserver') && len(split(serverlist(), "\n")) > 1 )
		cal ctrlp#clra()
	en
endf

fu! s:checkbuf()
	if !exists('s:init') && exists('s:bufnr') && s:bufnr > 0
		exe s:bufnr.'bw!'
	en
endf

fu! s:iscmdwin()
	let [ermsg, v:errmsg] = [v:errmsg, '']
	sil! noa winc p
	sil! noa winc p
	let [v:errmsg, ermsg] = [ermsg, v:errmsg]
	retu ermsg =~ '^E11:'
endf
" Arguments {{{2
fu! s:at(str)
	if a:str =~ '\v^\@(cd|lc[hd]?|chd).*'
		let str = substitute(a:str, '\v^\@(cd|lc[hd]?|chd)\s*', '', '')
		if str == '' | retu 1 | en
		let str = str =~ '^%:.\+' ? fnamemodify(s:crfile, str[1:]) : str
		let path = fnamemodify(expand(str, 1), ':p')
		if isdirectory(path)
			if path != s:dyncwd
				cal ctrlp#setdir(path)
				cal ctrlp#setlines()
			en
			cal ctrlp#recordhist()
			cal s:PrtClear()
		en
		retu 1
	en
	retu 0
endf

fu! s:tail()
	if exists('s:optail') && !empty('s:optail')
		let tailpref = s:optail !~ '^\s*+' ? ' +' : ' '
		retu tailpref.s:optail
	en
	retu ''
endf

fu! s:sanstail(str)
	let str = s:spi ?
		\ substitute(a:str, '^\(@.*$\|\\\\\ze@\|\.\.\zs[.\/]\+$\)', '', 'g') : a:str
	let [str, pat] = [substitute(str, '\\\\', '\', 'g'), '\([^:]\|\\:\)*$']
	unl! s:optail
	if str =~ '\\\@<!:'.pat
		let s:optail = matchstr(str, '\\\@<!:\zs'.pat)
		let str = substitute(str, '\\\@<!:'.pat, '', '')
	en
	retu substitute(str, '\\\ze:', '', 'g')
endf

fu! s:argmaps(md, i)
	let roh = [
		\ ['Open Multiple Files', '/h[i]dden/[c]lear', ['i', 'c']],
		\ ['Create a New File', '/[r]eplace', ['r']],
		\ ['Open Selected', '/[r]eplace', ['r', 'd', 'a']],
		\ ]
	if a:i == 2
		if !buflisted(bufnr('^'.fnamemodify(ctrlp#getcline(), ':p').'$'))
			let roh[2][1] .= '/h[i]dden'
			let roh[2][2] += ['i']
		en
		if s:openfunc != {} && has_key(s:openfunc, s:ctype)
			let roh[2][1] .= '/e[x]ternal'
			let roh[2][2] += ['x']
		en
	en
	let str = roh[a:i][0].': [t]ab/[v]ertical/[h]orizontal'.roh[a:i][1].'? '
	retu s:choices(str, ['t', 'v', 'h'] + roh[a:i][2], 's:argmaps', [a:md, a:i])
endf

fu! s:insertstr()
	let str = 'Insert: c[w]ord/c[f]ile/[s]earch/[v]isual/[c]lipboard/[r]egister? '
	retu s:choices(str, ['w', 'f', 's', 'v', 'c', 'r'], 's:insertstr', [])
endf

fu! s:textdialog(str)
	redr | echoh MoreMsg | echon a:str | echoh None
	retu nr2char(getchar())
endf

fu! s:choices(str, choices, func, args)
	let char = s:textdialog(a:str)
	if index(a:choices, char) >= 0
		retu char
	elsei char =~# "\\v\<Esc>|\<C-c>|\<C-g>|\<C-u>|\<C-w>|\<C-[>"
		cal s:OnUpdatedState(1, 0)
		retu 'cancel'
	elsei char =~# "\<CR>" && a:args != []
		retu a:args[0]
	en
	retu call(a:func, a:args)
endf

fu! s:getregs()
	let char = s:textdialog('Insert from register: ')
	if char =~# "\\v\<Esc>|\<C-c>|\<C-g>|\<C-u>|\<C-w>|\<C-[>"
		cal s:OnUpdatedState(1, 0)
		retu -1
	elsei char =~# "\<CR>"
		retu s:getregs()
	en
	retu s:regisfilter(char)
endf

fu! s:regisfilter(reg)
	retu substitute(getreg(a:reg), "[\t\n]", ' ', 'g')
endf
" Misc {{{2
fu! s:modevar()
	let s:matchtype = s:mtype()
	let s:ispath = s:ispathitem()
	let s:mfunc = s:mfunc()
	let s:nolim = s:getextvar('nolim')
	let s:dosort = s:getextvar('sort')
	let s:spi = !s:itemtype || s:getextvar('specinput') > 0
endf

fu! s:nosort()
	let ct = s:curtype()
	retu s:matcher != {} || s:nolim == 1 || ( ct == 'mru' && s:mrudef )
		\ || ( ct =~ '^\(buf\|mru\)$' && s:prompt == ['', '', ''] ) || !s:dosort
endf

fu! s:byfname()
	retu s:curtype() != 'buf' && s:ispath && s:byfname
endf

fu! s:narrowable()
	retu exists('s:act_add') && exists('s:matched') && s:matched != []
		\ && exists('s:mdata') && s:mdata[:2] == [s:dyncwd, s:itemtype, s:regexp]
		\ && s:matcher == {} && !exists('s:did_exp')
endf

fu! s:getinput(...)
	let [prt, spi] = [s:prompt, ( a:0 ? a:1 : '' )]
	if s:abbrev != {}
		let gmd = has_key(s:abbrev, 'gmode') ? s:abbrev['gmode'] : ''
		let str = ( gmd =~ 't' && !a:0 ) || spi == 'c' ? prt[0] : join(prt, '')
		if gmd =~ 't' && gmd =~ 'k' && !a:0 && matchstr(str, '.$') =~ '\k'
			retu join(prt, '')
		en
		let [pf, rz] = [( s:byfname() ? 'f' : 'p' ), ( s:regexp ? 'r' : 'z' )]
		for dict in s:abbrev['abbrevs']
			let dmd = has_key(dict, 'mode') ? dict['mode'] : ''
			let pat = escape(dict['pattern'], '~')
			if ( dmd == '' || ( dmd =~ pf && dmd =~ rz && !a:0 )
				\ || dmd =~ '['.spi.']' ) && str =~ pat
				let [str, s:did_exp] = [join(split(str, pat, 1), dict['expanded']), 1]
			en
		endfo
		if gmd =~ 't' && !a:0
			let prt[0] = str
		el
			retu str
		en
	en
	retu spi == 'c' ? prt[0] : join(prt, '')
endf

fu! s:strwidth(str)
	retu exists('*strdisplaywidth') ? strdisplaywidth(a:str) : strlen(a:str)
endf

fu! ctrlp#j2l(nr)
	exe 'norm!' a:nr.'G'
	sil! norm! zvzz
endf

fu! s:maxf(len)
	retu s:maxfiles && a:len > s:maxfiles
endf

fu! s:regexfilter(str)
	let str = a:str
	for key in keys(s:fpats) | if str =~ key
		let str = substitute(str, s:fpats[key], '', 'g')
	en | endfo
	retu str
endf

fu! s:walker(m, p, d)
	retu a:d >= 0 ? a:p < a:m ? a:p + a:d : 0 : a:p > 0 ? a:p + a:d : a:m
endf

fu! s:delent(rfunc)
	if a:rfunc == '' | retu | en
	let [s:force, tbrem] = [1, []]
	if exists('s:marked')
		let tbrem = values(s:marked)
		cal s:unmarksigns()
		unl s:marked
	en
	if tbrem == [] && ( has('dialog_gui') || has('dialog_con') ) &&
		\ confirm("Wipe all entries?", "&OK\n&Cancel") != 1
		unl s:force
		cal s:OnUpdatedState(1, 0)
		retu
	en
	" DEBUG: echomsg printf( 'DEBUG: lines before removal. len=%d; list=%s', len(g:ctrlp_lines), string(g:ctrlp_lines) )
	" DEBUG: echomsg printf( 'DEBUG: lines before removal. len=%d; edge_items=%s; tbrem=%s', len(g:ctrlp_lines), string(g:ctrlp_lines[:5]), string(tbrem) )
	let g:ctrlp_lines = call(a:rfunc, [tbrem])
	" DEBUG: echomsg printf( 'DEBUG: lines after removal. len=%d; list=%s', len(g:ctrlp_lines), string(g:ctrlp_lines) )
	" DEBUG: echomsg printf( 'DEBUG: lines after removal. len=%d; edge_items=%s; tbrem=%s', len(g:ctrlp_lines), string(g:ctrlp_lines[:5]), string(tbrem) )
	cal s:OnUpdatedState(1, 1)
	unl s:force
endf

fu! s:delbufcond(bufnr)
	retu getbufvar(a:bufnr, "&mod") || a:bufnr == s:crbufnr
endf

fu! s:delbuf()
	let lines = []
	if exists('s:marked')
		let lines = values(s:marked)
		cal s:unmarksigns()
		unl s:marked
	el
		let lines += [ctrlp#getcline()]
	en
	for line in lines
		let bufnr = s:bufnrfilpath(line)[0]
		if (s:delbufcond(bufnr))
			con
		en
		exe 'bd '. bufnr
	endfo
	cal s:PrtClearCache()
endf

fu! s:isterminal(buf)
	retu getbufvar(a:buf, "&bt") == "terminal"
endf
" Entering & Exiting {{{2
fu! s:getenv()
	let [s:cwd, s:winres] = [getcwd(), [winrestcmd(), &lines, winnr('$')]]
	let [s:crword, s:crnbword] = [expand('<cword>', 1), expand('<cWORD>', 1)]
	let [s:crgfile, s:crline] = [expand('<cfile>', 1), getline('.')]
	let [s:winmaxh, s:crcursor] = [min([s:mw_max, &lines]), getpos('.')]
	let [s:crbufnr, s:crvisual] = [bufnr('%'), s:lastvisual()]
	let s:crfile = bufname('%') == ''
		\ ? '['.s:crbufnr.'*No Name]' : expand('%:p', 1)
	let s:crfpath = expand('%:p:h', 1)
	let s:mrbs = ctrlp#mrufiles#bufs()
	unl! s:last_invocation_env_dict
endf

" returns a dictionary with some of the variables loaded in 's:getenv()'.
" NOTE: the dictionary elements do not hold copies of "reference" objects,
" such as lists and dictionaries.  If the caller needs to operate on the
" values, it needs to make copies or make sure it would not change the objects
" pointed to by those dictionary entries.
" Returns a (possibly cached) dictionary object, which could be empty if this
" call has been made after calling 'ctrlp#exit()' (or 's:PrtExit()', etc.)
" NOTE: the dictionary entries themselves might be re-assigned, but we can
" assume the values themselves are immutable.  Therefore, a 'copy()' is enough
" (no need to call 'deepcopy()' on the reutrn value).
fu! ctrlp#get_last_invocation_env()
	if !exists('s:init') | retu {} | en
	if !exists('s:last_invocation_env_dict')
		" NOTE: variables like 's:crfilerel' can change during 'ctrlp's execution
		" ('ctrlp#setdir()').
		"  QUESTION: could some of these other values change, too?
		let s:last_invocation_env_dict = {
			\		'crword': s:crword,
			\		'crnbword': s:crnbword,
			\		'crgfile': s:crgfile,
			\		'crline': s:crline,
			\		'crcursor': s:crcursor,
			\		'crbufnr': s:crbufnr,
			\		'cwd': s:cwd,
			\		'crfile': s:crfile,
			\		'crfpath': s:crfpath,
			\ }
	en
	retu s:last_invocation_env_dict
endf

fu! s:lastvisual()
	let cview = winsaveview()
	let [ovreg, ovtype] = [getreg('v'), getregtype('v')]
	let [oureg, outype] = [getreg('"'), getregtype('"')]
	sil! norm! gV"vy
	let selected = s:regisfilter('v')
	cal setreg('v', ovreg, ovtype)
	cal setreg('"', oureg, outype)
	cal winrestview(cview)
	retu selected
endf

fu! s:log(m)
	if exists('g:ctrlp_log') && g:ctrlp_log | if a:m
		let cadir = ctrlp#utils#cachedir()
		let apd = g:ctrlp_log > 1 ? '>' : ''
		sil! exe 'redi! >'.apd cadir.s:lash(cadir).'ctrlp.log'
	el
		sil! redi END
	en | en
endf

fu! s:buffunc(e)
	if a:e && has_key(s:buffunc, 'enter')
		cal call(s:buffunc['enter'], [], s:buffunc)
	elsei !a:e && has_key(s:buffunc, 'exit')
		cal call(s:buffunc['exit'], [], s:buffunc)
	en
endf

fu! s:openfile(cmd, fid, tail, chkmod, ...)
	let cmd = a:cmd
	if a:chkmod && cmd =~ '^[eb]$' && ctrlp#modfilecond(!( cmd == 'b' && &aw ))
		let cmd = cmd == 'b' ? 'sb' : 'sp'
	en
	let cmd = cmd =~ '^tab' ? ctrlp#tabcount().cmd : cmd
	let j2l = a:0 && a:1[0] ? a:1[1] : 0
	exe cmd.( a:0 && a:1[0] ? '' : a:tail ) s:fnesc(a:fid, 'f')
	if j2l
		cal ctrlp#j2l(j2l)
	en
	if !empty(a:tail)
		sil! norm! zvzz
	en
	if cmd != 'bad'
		cal ctrlp#setlcdir()
	en
endf

fu! ctrlp#tabcount()
	if exists('s:tabct')
		let tabct = s:tabct
		let s:tabct += 1
	elsei !type(s:tabpage)
		let tabct = s:tabpage
	elsei type(s:tabpage) == 1
		let tabpos =
			\ s:tabpage =~ 'c' ? tabpagenr() :
			\ s:tabpage =~ 'f' ? 1 :
			\ s:tabpage =~ 'l' ? tabpagenr('$') :
			\ tabpagenr()
		let tabct =
			\ s:tabpage =~ 'a' ? tabpos :
			\ s:tabpage =~ 'b' ? tabpos - 1 :
			\ tabpos
	en
	retu tabct < 0 ? 0 : tabct
endf

fu! s:settype(type)
	retu a:type < 0 ? exists('s:itemtype') ? s:itemtype : 0 : a:type
endf
" Matching {{{2
fu! s:matchfname(item, pat)
	let parts = split(a:item, '[\/]\ze[^\/]\+$')
	let mfn = match(parts[-1], a:pat[0])
	retu len(a:pat) == 1 ? mfn : len(a:pat) == 2 ?
		\ ( mfn >= 0 && ( len(parts) == 2 ? match(parts[0], a:pat[1]) : -1 ) >= 0
		\ ? 0 : -1 ) : -1
endf

fu! s:matchbuf(item, pat)
	let bufnr = s:bufnrfilpath(a:item)[0]
	let parts = s:bufparts(bufnr)
	let item = s:byfname ? parts[2] : bufnr.parts[0].s:getpathamefrombufparts(parts)
	retu match(item, a:pat)
endf

fu! s:matchtabs(item, pat)
	retu match(split(a:item, '\t\+')[0], a:pat)
endf

fu! s:matchtabe(item, pat)
	retu match(split(a:item, '\t\+[^\t]\+$')[0], a:pat)
endf

" FIXME: we should consider several aspects of the current "match type" in
" order to:
"  * skip the optional line marker at the beginning of the line (this can
"    always be skipped for every line, maybe by using a zero-length match or
"    something more efficient?);
"  * choose the right value(s) to match something more specific than just:
"    'x[^x/]' (s:matchnatural) or 'x[^x]' (otherwise).
" IDEA: accept an (optional?) argument with the forbidden characters
"  (when matching with a match type of "data is up to the first tab", we could
"  specify '\t' for example).
" NOTE: we want to create a regex that is efficient and that won't match
"  things we don't want it to.
fu! s:buildpat(lst)
	let pat = a:lst[0]
	if s:matchnatural == 1
		for item in range(1, len(a:lst) - 1)
			let c = a:lst[item - 1]
			let pat .= (c == '/' ? '[^/]\{-}' : '[^'.c.'/]\{-}').a:lst[item]
		endfo
	els
		for item in range(1, len(a:lst) - 1)
			let pat .= '[^'.a:lst[item - 1].']\{-}'.a:lst[item]
		endfo
	en
	retu pat
endf

fu! s:curtype()
	return s:CurTypeName()[1]
endf

fu! s:mfunc()
	let mfunc = 'match'
	if s:byfname()
		let mfunc = 's:matchfname'
	elsei s:curtype() == 'buf'
		let mfunc = 's:matchbuf'
	elsei s:itemtype >= len(s:coretypes)
		let matchtypes = { 'tabs': 's:matchtabs', 'tabe': 's:matchtabe' }
		if has_key(matchtypes, s:matchtype)
			let mfunc = matchtypes[s:matchtype]
		en
	en
	retu mfunc
endf

fu! s:mmode()
	let matchmodes = {
		\ 'match': 'full-line',
		\ 's:matchfname': 'filename-only',
		\ 's:matchbuf': s:byfname ? 'filename-only' : 'full-line',
		\ 's:matchtabs': 'first-non-tab',
		\ 's:matchtabe': 'until-last-tab',
		\ }
	retu matchmodes[s:mfunc]
endf
" Cache {{{2
fu! s:writecache(cafile)
	if ( g:ctrlp_newcache || !filereadable(a:cafile) ) && !s:nocache()
		cal ctrlp#utils#writecache(g:ctrlp_allfiles)
		let g:ctrlp_newcache = 0
	en
endf

fu! s:nocache(...)
	if !s:caching
		retu 1
	elsei s:caching > 1
		if !( exists(s:ccex) && !{s:ccex} ) || has_key(s:ficounts, s:dyncwd)
			retu get(s:ficounts, s:dyncwd, [0, 0])[0] < s:caching
		elsei a:0 && filereadable(a:1)
			retu len(ctrlp#utils#readfile(a:1)) < s:caching
		en
		retu 1
	en
	retu 0
endf

fu! s:insertcache(str)
	let [data, g:ctrlp_newcache, str] = [g:ctrlp_allfiles, 1, a:str]
	if data == [] || strlen(str) <= strlen(data[0])
		let pos = 0
	elsei strlen(str) >= strlen(data[-1])
		let pos = len(data) - 1
	el
		let pos = 0
		for each in data
			if strlen(each) > strlen(str) | brea | en
			let pos += 1
		endfo
	en
	cal insert(data, str, pos)
	cal s:writecache(ctrlp#utils#cachefile())
endf
" Extensions {{{2
fu! s:mtype()
	retu s:itemtype >= len(s:coretypes) ? s:getextvar('type') : 'path'
endf

fu! s:execextvar(key)
	if !empty(g:ctrlp_ext_vars)
		cal map(filter(copy(g:ctrlp_ext_vars),
			\ 'has_key(v:val, a:key)'), 'eval(v:val[a:key])')
	en
endf

fu! s:getextvar(key)
	if s:itemtype >= len(s:coretypes) && len(g:ctrlp_ext_vars) > 0
		let vars = g:ctrlp_ext_vars[s:itemtype - len(s:coretypes)]
		if has_key(vars, a:key)
			retu vars[a:key]
		en
	en
	retu get(g:, 'ctrlp_' . s:matchtype . '_' . a:key, -1)
endf

fu! ctrlp#getcline()
	let [linenr, offset] = [line('.'), ( s:offset > 0 ? s:offset : 0 )]
	retu !empty(s:lines) && !( offset && linenr <= offset )
		\ ? s:lines[linenr - 1 - offset] : ''
endf

fu! ctrlp#getmarkedlist()
	retu exists('s:marked') ? values(s:marked) : []
endf

fu! ctrlp#clearmarkedlist()
	let s:marked = {}
endf

fu! ctrlp#exit()
	cal s:PrtExit()
endf

fu! ctrlp#prtclear()
	cal s:PrtClear()
endf

fu! ctrlp#switchtype(id)
	cal s:ToggleType(a:id - s:itemtype)
endf

fu! ctrlp#nosy()
	retu !( has('syntax') && exists('g:syntax_on') )
endf

fu! ctrlp#hicheck(grp, defgrp)
	if !hlexists(a:grp)
		exe 'hi link' a:grp a:defgrp
	en
endf

fu! ctrlp#call(func, ...)
	retu call(a:func, a:000)
endf

fu! ctrlp#getvar(var)
	retu {a:var}
endf
" Ezequiel - Logging {{{2
let s:ev_log_flag = get(g:, 'ctrlp_ev_log', 0)
let s:ev_log_printf = function('printf')
function! ctrlp#ev_log_printf(...)
	if !s:ev_log_flag | retu | en
	if ( ! exists( 'g:ev_test_log' ) )
		let g:ev_test_log = []
	endif
	call add(
		\	g:ev_test_log,
		\	printf(
		\		'[%s] %s',
		\		strftime('%Y.%m.%d %H:%M:%S'),
		\		( a:0 > 1 ? call( s:ev_log_printf, a:000 ) : get(a:000, 0, '') )
		\	))
endfunction
"}}}1
" * Initialization {{{1
fu! s:setlines_pre(...)
	if a:0 | let s:itemtype = a:1 | en
	cal s:modevar()
	let g:ctrlp_lines = []
endf

fu! s:setlines_post()
	let log_pref = 's:setlines_post(): '
	let inits = {'fil': 'ctrlp#files()', 'buf': 'ctrlp#buffers()', 'mru': 'ctrlp#mrufiles#list()'}
	let types = map(copy(g:ctrlp_types), 'inits[v:val]')
	if !empty(g:ctrlp_ext_vars)
		cal map(copy(g:ctrlp_ext_vars), 'add(types, v:val["init"])')
	en
	let g:ctrlp_lines = eval(types[s:itemtype])
	cal ctrlp#ev_log_printf(
		\	log_pref . ' about to return. len(g:ctrlp_lines)=%d;',
		\	len(g:ctrlp_lines))
endf

fu! ctrlp#setlines(...)
	cal call('s:setlines_pre', a:000)
	cal s:setlines_post()
endf

" Returns [lname, sname]
fu! s:CurTypeName()
	if s:itemtype < len(s:coretypes)
		return filter(copy(s:coretypes), 'v:val[1]==g:ctrlp_types[s:itemtype]')[0]
	el
		return [s:getextvar("lname"), s:getextvar('sname')]
	en
endfu

fu! s:ExitIfSingleCandidate()
	if len(s:Update(s:prompt[0])) == 1
		call s:AcceptSelection('e')
		call ctrlp#exit()
		return 1
	en
	return 0
endfu

fu! s:IsBuiltin()
	let builtins = ['tag', 'dir', 'bft', 'rts', 'bkd', 'lns', 'chs', 'mix', 'udo', 'qfx']
	let curtype = s:getextvar('sname')
	return s:itemtype < len(s:coretypes) || index(builtins, curtype) > -1
endfu

fu! s:DetectFileType(type, ft)
	if s:IsBuiltin() || empty(a:ft) || a:ft ==# 'ctrlp'
		retu 'ctrlp'
	el
		retu 'ctrlp.' . a:ft
	en
endfu

fu! ctrlp#init(type, ...)
	if exists('s:init') || s:iscmdwin() | retu | en
	let [s:ermsg, v:errmsg] = [v:errmsg, '']
	let [s:matches, s:init] = [1, 1]
	cal s:Reset(a:0 ? a:1 : {})
	noa cal s:Open()
	cal s:SetWD(a:0 ? a:1 : {})
	cal s:MapNorms()
	cal s:MapSpecs()
	if empty(g:ctrlp_types) && empty(g:ctrlp_ext_vars)
		call ctrlp#exit()
		retu
	en
	if type(a:type) == 0
		let type = a:type
	el
		let type = index(g:ctrlp_types, a:type)
		if type == -1
			call ctrlp#exit()
			retu
		en
	en
	" Fixed issue ctrlpvim/ctrlp.vim#463 : Opening 'ctrlp' in certain modes
	" (':CtrlPBufTag', ':CtrlPLine') seems to trigger a partially deffective
	" intialisation (for example, syntax highlighting not working as expected).
	" Fix: ctrlp#setlines() split in two, as the second part (now in
	" s:setlines_post()) seems to need '&filetype', and s:DetectFileType() seems
	" to need the first part of the old ctrlp#setlines() (now in
	" s:setlines_pre()).
	cal s:setlines_pre(s:settype(type))
	let &filetype = s:DetectFileType(type, &filetype)
	cal s:setlines_post()
	" DEBUG: cal ctrlp#ev_log_printf( 'DEBUG: init: after s:setlines_post(): len(g:ctrlp_lines)=%d', len(g:ctrlp_lines) )
	cal ctrlp#syntax()
	cal s:SetDefTxt()
	let curName = s:CurTypeName()
	let shouldExitSingle = index(s:opensingle, curName[0])>=0 || index(s:opensingle, curName[1])>=0
	if shouldExitSingle && s:ExitIfSingleCandidate()
		cal ctrlp#ev_log_printf('ctrlp#init(): exiting after a single candidate has been found')
		return 0
	en
	cal s:OnUpdatedState(1, 1)
	if s:keyloop | cal s:KeyLoop() | en
	return 1
endf
" - Autocmds {{{1
if has('autocmd')
	aug CtrlPAug
		au!
		au BufEnter ControlP cal s:checkbuf()
		au BufLeave ControlP noa cal s:Close()
		au VimLeavePre * cal s:leavepre()
	aug END
en

fu! s:autocmds()
	if !has('autocmd') | retu | en
	if exists('#CtrlPLazy')
		au! CtrlPLazy
	en
	if s:lazy
		aug CtrlPLazy
			au!
			au CursorHold ControlP cal s:ForceUpdate()
		aug END
	en
endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
