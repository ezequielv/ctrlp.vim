" =============================================================================
" File:          autoload/ctrlp/buffertag.vim
" Description:   Buffer Tag extension
" Maintainer:    Kien Nguyen <github.com/kien>
" Credits:       Much of the code was taken from tagbar.vim by Jan Larres, plus
"                a few lines from taglist.vim by Yegappan Lakshmanan and from
"                buffertag.vim by Takeshi Nishida.
" =============================================================================

" Init {{{1
if exists('g:loaded_ctrlp_buftag') && g:loaded_ctrlp_buftag
	fini
en
let g:loaded_ctrlp_buftag = 1

let s:initonce_done = 0
let s:entered_count = 0

cal add(g:ctrlp_ext_vars, {
	\ 'init': 'ctrlp#buffertag#init(s:crfile)',
	\ 'accept': 'ctrlp#buffertag#accept',
	\ 'lname': 'buffer tags',
	\ 'sname': 'bft',
	\ 'exit': 'ctrlp#buffertag#exit()',
	\ 'type': 'tabs',
	\ 'opts': 'ctrlp#buffertag#opts()',
	\ })

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

let [s:pref, s:opts] = ['g:ctrlp_buftag_', {
	\ 'systemenc': ['s:enc', &enc],
	\ 'ctags_bin': ['s:bin', ''],
	\ 'types': ['s:usr_types', {}],
	\ 'linesfrombuffer': ['s:linesfrombuffer_flag', 1],
	\ 'cache_mru_maxage': ['s:cache_mru_maxage', 10],
	\ 'cache_mru_dupcounts': ['s:cache_mru_dupcounts', 0],
	\	'findtagcmd_verb': ['s:findtagcmd_verb_def', 'findtag_searchnearby'],
	\ }]

let s:bins = [
	\ 'ctags-exuberant',
	\ 'exuberant-ctags',
	\ 'exctags',
	\ '/usr/local/bin/ctags',
	\ '/opt/local/bin/ctags',
	\ 'ctags',
	\ 'ctags.exe',
	\ 'tags',
	\ ]

let s:types = {
	\ 'ant'    : '%sant%sant%spt',
	\ 'asm'    : '%sasm%sasm%sdlmt',
	\ 'aspperl': '%sasp%sasp%sfsv',
	\ 'aspvbs' : '%sasp%sasp%sfsv',
	\ 'awk'    : '%sawk%sawk%sf',
	\ 'beta'   : '%sbeta%sbeta%sfsv',
	\ 'c'      : '%sc%sc%sdgsutvf',
	\ 'cpp'    : '%sc++%sc++%snvdtcgsuf',
	\ 'cs'     : '%sc#%sc#%sdtncEgsipm',
	\ 'cobol'  : '%scobol%scobol%sdfgpPs',
	\ 'delphi' : '%spascal%spascal%sfp',
	\ 'dosbatch': '%sdosbatch%sdosbatch%slv',
	\ 'eiffel' : '%seiffel%seiffel%scf',
	\ 'erlang' : '%serlang%serlang%sdrmf',
	\ 'expect' : '%stcl%stcl%scfp',
	\ 'fortran': '%sfortran%sfortran%spbceiklmntvfs',
	\ 'go'     : '%sgo%sgo%sfctv',
	\ 'html'   : '%shtml%shtml%saf',
	\ 'java'   : '%sjava%sjava%spcifm',
	\ 'javascript': '%sjavascript%sjavascript%sf',
	\ 'lisp'   : '%slisp%slisp%sf',
	\ 'lua'    : '%slua%slua%sf',
	\ 'make'   : '%smake%smake%sm',
	\ 'matlab' : '%smatlab%smatlab%sf',
	\ 'ocaml'  : '%socaml%socaml%scmMvtfCre',
	\ 'pascal' : '%spascal%spascal%sfp',
	\ 'perl'   : '%sperl%sperl%sclps',
	\ 'php'    : '%sphp%sphp%scdvf',
	\ 'python' : '%spython%spython%scmf',
	\ 'rexx'   : '%srexx%srexx%ss',
	\ 'ruby'   : '%sruby%sruby%scfFm',
	\ 'rust'   : '%srust%srust%sfTgsmctid',
	\ 'scheme' : '%sscheme%sscheme%ssf',
	\ 'sh'     : '%ssh%ssh%sf',
	\ 'csh'    : '%ssh%ssh%sf',
	\ 'zsh'    : '%ssh%ssh%sf',
	\ 'scala'  : '%sscala%sscala%sctTmlp',
	\ 'slang'  : '%sslang%sslang%snf',
	\ 'sml'    : '%ssml%ssml%secsrtvf',
	\ 'sql'    : '%ssql%ssql%scFPrstTvfp',
	\ 'tex'    : '%stex%stex%sipcsubPGl',
	\ 'tcl'    : '%stcl%stcl%scfmp',
	\ 'vera'   : '%svera%svera%scdefgmpPtTvx',
	\ 'verilog': '%sverilog%sverilog%smcPertwpvf',
	\ 'vhdl'   : '%svhdl%svhdl%sPctTrefp',
	\ 'vim'    : '%svim%svim%savf',
	\ 'yacc'   : '%syacc%syacc%sl',
	\ }

cal map(s:types, 'printf(v:val, "--language-force=", " --", "-types=")')

if executable('jsctags')
	cal extend(s:types, { 'javascript': { 'args': '-f -', 'bin': 'jsctags' } })
en

" see ':help mkdir()'
let s:tempfiles_base_isdir = exists('*mkdir') && ctrlp#utils#can_remove_directories()

fu! ctrlp#buffertag#opts()
	for [ke, va] in items(s:opts)
		let {va[0]} = exists(s:pref.ke) ? {s:pref.ke} : va[1]
	endfo
	" Ctags bin
	if empty(s:bin)
		for bin in s:bins | if executable(bin)
			let s:bin = bin
			brea
		en | endfo
	el
		let s:bin = expand(s:bin, 1)
	en
	" Types
	cal extend(s:types, s:usr_types)
endf
" Utilities {{{1
"  IDEA: initially, individual components are considered, left-to-right
"   (so, 'c.doxygen' will try 'c' first, then 'doxygen', which could be parsed
"   separately of the main type was not supported).
"   IDEA: have the non-main types supported optionally through a new entry in
"   's:opts'.
" IDEA: support the 'filetype' override for the 'tagbar' plugin (there's a
" buffer-local variable for this, IIRC).
" MAYBE: add support for the extensions used in 'tagbar' (see ':h tagbar-extend')
"  NOTE: interesting variables: 'g:tagbar_type_{vim_filetype}', 'b:tagbar_type'.
"  NOTE: this might be complicated, as we'll have to replicate the processing
"   of those definition dictionaries as 'tagbar' does it, with forward and
"   backward compatibility.
"   IDEA: an idea would be to use a single-run entry for the 'ftype' used
"    in the processing of each file, and allocate a temporary (but reusable,
"    if the 'g:tagbar_type_{vim_filetype}' was used, for example) entry in
"    's:opts', and also do the same 'kinds' dictionary entry parsing and
"    associated per-'tags(5)'-entry processing that 'tagbar' does.
" for now, only the first supported component in a multi-component value is
" considered.
fu! s:get_ctags_ftype(fname)
	let filetypes_sup = split(getbufvar(a:fname, '&filetype'), '\.')
	if empty(filetypes_sup) | retu '' | en
	retu get(filter(filetypes_sup, 'has_key(s:types, v:val)'), 0, '')
endf

" optional args: [ftype]
"  ftype:
"   default: calculated/retrieved from fname/the buffer corresponding to
"            fname ('s:get_ctags_ftype()').
fu! s:validfile(fname, ...)
	if empty(a:fname) | retu 0 | en
	let ftype = a:0 > 0 ? a:1 : s:get_ctags_ftype(a:fname)
	if empty(ftype) || index(keys(s:types), ftype) < 0 | retu 0 | en
	" allow files to be tagged from buffers when they're not readable.
	retu 1
endf

fu! s:exectags(cmd)
	if exists('+ssl')
		let [ssl, &ssl] = [&ssl, 0]
	en
	if &sh =~ 'cmd\.exe'
		let [sxq, &sxq, shcf, &shcf] = [&sxq, '"', &shcf, '/s /c']
	en
	let output = system(a:cmd)
	if &sh =~ 'cmd\.exe'
		let [&sxq, &shcf] = [sxq, shcf]
	en
	if exists('+ssl')
		let &ssl = ssl
	en
	retu output
endf

" return value: a 2-element list:
"  [0]: 'ctags(1)' command output (if any);
"  [1]: whether that output should be considered a "precise" match against the
"       current buffer contents.
fu! s:exectagsonfile(fname, ftype, ctags_use_origfile)
	let retnocontent = ['', 0]
	let [ags, ft] = ['-f - --sort=no --excmd=pattern --fields=nKs --extra= --file-scope=yes ', a:ftype]
	if type(s:types[ft]) == 1
		let ags .= s:types[ft]
		let bin = s:bin
	elsei type(s:types[ft]) == 4
		let ags = s:types[ft]['args']
		let bin = expand(s:types[ft]['bin'], 1)
	en
	if empty(bin) | retu retnocontent | en

	let fname_ctags = ''
	try
		if !a:ctags_use_origfile
			let fname_ctags = s:tmpfilenamefor(a:fname, a:ftype)
			let fname_ctags_istmp = !0
			let match_use_bufcontents = !0
			" forcibly write the lines to that file, and use the original file as a
			" fallback if that didn't work.
			" NOTE: the ':sil[ent]' prefix avoids error messages being logged/written,
			" but we can still react to errors by storing the return value from
			" 'writefile()'.
			if !empty(fname_ctags)
				sil let rc = writefile(getbufline(a:fname, 1, '$'), fname_ctags)
				" MAYBE: report error?
				if rc < 0 | let fname_ctags = '' | en
			en
			" NOTE: a more "complete" condition has been used in our caller to
			" determine whether to set 'a:ctags_use_origfile', so the condition here
			" is only to see whether it makes sense to use the original file as a
			" fallback.
			if empty(fname_ctags)
				if !(
					\ (!ctrlp#utils#fname_is_virtual(a:fname))
					\ && filereadable(a:fname))
					retu retnocontent
				en
			en
		en
		if empty(fname_ctags)
			let fname_ctags = a:fname
			let fname_ctags_istmp = 0
			" when using the original file for producing tags, we will consider the
			" "tag source" as matching the buffer contents when such buffer does not
			" have the 'modified' flag set.
			let match_use_bufcontents = !getbufvar(a:fname, '&modified')
		en

		let cmd = s:esctagscmd(bin, ags, fname_ctags)
		if empty(cmd) | retu retnocontent | en
		let output = s:exectags(cmd)
		if v:shell_error || output =~ 'Warning: cannot open' | retu retnocontent | en
		retu [output, match_use_bufcontents]

	fina
		" save disc space by truncating the *temporary* file we've just used.
		" NOTE: condition is designed to only match against non-empty temporary
		" files.
		if (!empty(fname_ctags)) && fname_ctags_istmp
					\ && (!empty(readfile(fname_ctags, '', 1)))
				" create an empty(-ish) file.
				" NOTE: this will stress the filesystem directory structure less
				" (hopefully) than removing the file, as there could be several files
				" with the same "leafname" that will end up being mapped to the same
				" temporary filename, thus resulting in potentially unnecessary
				" 'writefile(), delete(), writefile()' operations, and we're thus
				" replacing those with 'writefile(real1), writefile(empty),
				" writefile(real2)' here.
				" NOTE: for now, we ignore errors here, as the only purpose of this
				" operation is to save disc space.
				sil let rc = writefile([], fname_ctags, 'b')
		en
	endt
endf

fu! s:esctagscmd(bin, args, ...)
	if exists('+ssl')
		let [ssl, &ssl] = [&ssl, 0]
	en
	let fname = a:0 ? ctrlp#utils#shellescape(a:1) : ''
	if  (has('win32') || has('win64'))
		let cmd = a:bin.' '.a:args.' '.fname
	else
		let cmd = ctrlp#utils#shellescape(a:bin).' '.a:args.' '.fname
	endif
	if &sh =~ 'cmd\.exe'
		let cmd = substitute(cmd, '[&()@^<>|]', '^\0', 'g')
	en
	if exists('+ssl')
		let &ssl = ssl
	en
	if has('iconv')
		let last = s:enc != &enc ? s:enc : !empty( $LANG ) ? $LANG : &enc
		let cmd = iconv(cmd, &enc, last)
	en
	retu cmd
endf

" NOTE: this file is not guaranteed to exist, and if it does exist it's not
" guaranteed to have a particular content (empty or otherwise).
" LATER: make the above behaviour configurable?
fu! s:tmpfilenamefor(fname, ftype)
	if !exists('s:tempfilenames')
		let s:tempfilenames = {}
	en

	let fname = fnamemodify(bufname(a:fname), ':p')
	let tempfname = ctrlp#tmpfm#get_tmpfilename_for(s:id, fnamemodify(fname, ':t'))

	" NOTE: we don't check whether this file exists or not, as we might be using
	" two files from different directories named the same way, and also we don't
	" want to rule out calling this function twice for the same file at
	" different points in the plugin execution.
	" NOTE: we also don't check whether there was an entry in this dictionary
	" for this key ('tempfname'), as we're only interested in the last file that
	" eacy temporary filename is mapped to.
	let s:tempfilenames[tempfname] = fname
	retu tempfname
endf

fu! s:rmtempfiles()
	try
		cal ctrlp#tmpfm#cleanup_for(s:id)
	fina
		unl! s:tempfilenames
	endt
endf

" optional args:
"		* bufexpr | pathname:
"			* bufexpr: same as the arg bufname() and bufnr()
"			* pathname: any pathname that exists in the filesystem.
" prev: "  fname: usually a value retrieved through 'bufname()'.
" prev: "   default: bufname('%')
fu! s:get_lines_cache_key(...) abort
	" NOTE: we're using 'bufnr()' now, as those can change for files that have
	" been ':bwipe'd, for example, and we don't want to be too clever about
	" caching previous file contents when we're really keeping buffer-related
	" lines here.
	" prev: " NOTE: it's possible that this is a pre-existing bug, so this might go in a
	" prev: " different branch (the code using this function should be taken as well, at
	" prev: " least minimally, to avoid propagating the decision as to what is the
	" prev: " actual key calculation, and keep it in a single place).
	" prev: " prev: let bname = fnamemodify(a:0 ? a:1 : bufname('%'), ':p')
	" prev: "? let bname = a:0 ? ( (type(a:1) == 0) ? bufname(a:1) : a:1 ) : bufname('%')
	" prev: "? let bname = fnamemodify(a:0 ? ( (type(a:1) == 0) ? bufname(a:1) : a:1 ) : bufname('%'), ':p')
	" prev: let bname = fnamemodify(a:0 ? a:1 : bufname('%'), ':p')
	" prev: let bufnr = bufnr(bname)

	" MAYBE: refactor the function (I think it's 's:...') in ctrlp.vim to
	" retrieve bufnr and bufname, or make a new one in ctrlp/utils.vim to do
	" that: ctrlp#utils#get_bufnr_and_bufname_for(bufexpr)
	" prev: if a:0 && (type(a:1) == 0)
	" prev: 	" NOTE: this could be "invalid" (-1) or a "magic" value (0).
	" prev: 	" prev: " prev: let bufnr = a:1
	" prev: 	" prev: " prev: let bname = bufname(bufnr)
	" prev: 	" prev: let [bufnr, bname] = [a:1, '']
	" prev: 	let [bufnr, bname] = [bufnr(a:1), '']
	" prev: elsei a:0
	" prev: 	" prev: let [bufnr, bname] = [-1, a:1]
	" prev: 	let bname = a:1
	" prev: 	" prev: " if there is a buffer that can use 'bname' as a valid '{expr}'
	" prev: 	" prev: " (see ':h bufname()')...
	" prev: 	let bufnr = bufnr(bname)
	" prev: 	" prev: " prev: if bufnr > 0
	" prev: 	" prev: " prev: 	" then the buffer name should be retrieved from vim itself.
	" prev: 	" prev: " prev: 	let bname = bufname(bufnr)
	" prev: 	" prev: " prev: " note: otherwise, leave bufnr as "invalid" and bname as it was.
	" prev: 	" prev: " prev: en
	" prev: 	" prev: " if we have found a bufnr, then retrieve the bufname later.
	" prev: 	" prev: if bufnr > 0 | let bname = '' | en
	" prev: else
	" prev: 	let [bufnr, bname] = [bufnr('%'), '']
	" prev: en
	" prev: if !( (bufnr > 0) || (!empty(bname)) )
	" prev: 	throw printf(
	" prev: 		\	'%s could not work out bufnr and bufname from args. a:000=%s;',
	" prev: 		\	except_pref, string(a:000))
	" prev: en
	" prev: " prev: if (bufnr > 0) && empty(bname)
	" prev: " prev: 	let bname = bufname(bufnr)
	" prev: " prev: elsei (!empty(bname)) && (!(bufnr > 0))
	" prev: " prev: 	let bufnr = bufnr(bname)
	" prev: " prev: en
	" prev: if (!empty(bname)) && (!(bufnr > 0))
	" prev: 	let bufnr = bufnr(bname)
	" prev: en
	" prev: if (bufnr > 0)
	" prev: 	let bname = bufname(bufnr)
	" prev: en
	" prev: "- we_can_use_either: if !((bufnr > 0) && (!empty(bname)))
	" prev: "- we_can_use_either: 	throw printf(
	" prev: "- we_can_use_either: 		\	'%s could not work out bufnr and bufname from args. ' .
	" prev: "- we_can_use_either: 		\		'a:000=%s; bufnr=%d; bname=%s;',
	" prev: "- we_can_use_either: 		\	except_pref, string(a:000), bufnr, string(bufname))
	" prev: "- we_can_use_either: en

	let bufexpr = a:0 ? a:1 : ''
	let [bufnr, bname] = [bufnr(bufexpr), ( (type(bufexpr) == 0) ? '' : bufexpr )]
	if bufnr > 0
		let bname = bufname(bufnr)
	en

	if ctrlp#utils#bufname_is_pathname(bname)
		let bname = fnamemodify(bname, ':p')
	en

	" guard against files that (somehow) do not have a buffer associated to
	" them.  For now, we still track them, but we'll keep them separate from the
	" ones that do have an associated buffer.
	retu bufnr >= 0 ? 'bufnr:' . bufnr : 'file:' . bname
endf

fu! s:update_mru_cache(bufs)
	let cache_keys_now = map(copy(a:bufs), 's:get_lines_cache_key(v:val)')
	if !exists('s:mru_cache_keys_dict')
		let s:mru_cache_keys_dict = {}
		" FIXME: remove the following line (debugging only)
		"  NOTE: expose the same object through a global variable
		let g:ctrlp_buftag_mru_cachekeys_dict = s:mru_cache_keys_dict
	en
	" store keys associated to the buffers to be processed as candidates for
	" this plugin use/invocation.
	let s:mru_cache_keys_dict[s:entered_count] = cache_keys_now

	" NOTE: use 0 to disable this auto-pruning/purging
	if s:cache_mru_maxage > 0
		let entered_count_todel_max = s:entered_count - s:cache_mru_maxage
		" remove "old" entries
		if entered_count_todel_max > 0
			let cache_count_todel_keys = filter(
				\ keys(s:mru_cache_keys_dict), 'v:val <= entered_count_todel_max')
			if !empty(cache_count_todel_keys)
				let cache_keys_seen = {}
				let default_buftags_cache_entry = {}
				for cache_keys_todel in
						\		map(
						\			copy(cache_count_todel_keys),
						\			's:mru_cache_keys_dict[v:val]')
					for cache_key_todel in
						\ filter(cache_keys_todel, '!has_key(cache_keys_seen, v:val)')
						let cache_keys_seen[cache_key_todel] = 1
						" as the keys to be searched for are just candidates (an entry
						" might have been used in a later 'ctrlp' invocation), we need to
						" check the 'entered_count' "timestamp-ish" value to avoid
						" removing entries that have been used more recently than the
						" "count threshold" to delete it.
						if has_key(g:ctrlp_buftags, cache_key_todel) &&
								\ (get(g:ctrlp_buftags[cache_key_todel], 'entered_count')
								\		<= entered_count_todel_max)
							" remove the "tag lines" cache entry
							unl g:ctrlp_buftags[cache_key_todel]
						en
					endfo
				endfo
				" remove selected entries from 's:mru_cache_keys_dict'
				for cache_count_todel_key in cache_count_todel_keys
					unl s:mru_cache_keys_dict[cache_count_todel_key]
				endfo
			en
		en
	en
endf

fu! s:process(fname, ftype)
	" NOTE: the only caller to this function now makes sure that a:fname is
	" always a 's:validfile()', but this call is not strictly guaranteed (at the
	" moment) to be equivalent to the one made when filtering the buffers list
	" at the beginning.  For example, the calls might end up specifying
	" different values for the optional 'ftype' parameter.
	if !s:validfile(a:fname, a:ftype) | retu [] | endif

	let file_modified_flag = getbufvar(a:fname, '&modified')
	let ctags_use_origfile =
		\ (!s:linesfrombuffer_flag || !file_modified_flag)
		\ && !ctrlp#utils#fname_is_virtual(a:fname)
		\ && filereadable(a:fname)

	" NOTE: this could be either a string (if the variable is not available), or
	" a number.
	" FIXME: vim-7.0: this 'getbufvar(any_buffer_name, 'changedtick')' returns
	" the empty string every time.
	"  done: create a function: ctrlp#utils#getbufchangedtick() that checks the
	"  return value of getbufvar() with (for example) strlen(rc) to see whether
	"  it's got a sensible (integer) value.  If it didn't, then it can use
	"  'noautocmd keepalt keepjumps (if available)', etc. to switch to the buffer,
	"  retrieve the variable with 'b:', and then switch back
	"   done: create a function to evaluate an expression in a buffer, returning
	"   to the previous one.
	"   done: then have ctrlp#utils#getbufvar(bufexp, varname,
	"   type_id_or_string_expr_to_validate_correct_value, defvalue) use that
	"   function.
	"   not_needed: then have ctrlp#utils#getbufchangedtick() call
	"   ctrlp#utils#getbufvar().
	" prev: let changedtick = getbufvar(a:fname, 'changedtick')
	"+? let changedtick = ctrlp#utils#getbufvar(a:fname, 'changedtick')
	" FIXME: remove: testing {{{
	if 0
		let changedtick = 1
	elseif 1
		let changedtick = ctrlp#utils#getbufvar(a:fname, 'changedtick')
	elseif 0
		let changedtick = getbufvar(a:fname, 'changedtick')
	else
		try
			let changedtick = ctrlp#utils#getbufvar(a:fname, 'changedtick')
			cal ctrlp#ev_log_printf(
				\	'ctrlp#utils#getbufvar() returned normally. changedtick=%d;',
				\	changedtick)
		cat
			cal ctrlp#ev_log_printf(
				\	'ctrlp#utils#getbufvar() threw an exception: v:exception=%s; v:throwpoint=%s;',
				\	string(v:exception), string(v:throwpoint))
			let changedtick = getbufvar(a:fname, 'changedtick')
		endt
	endif
	" }}}
	let change_id_val = ctags_use_origfile
		\ ? 'ftime:' . getftime(a:fname)
		\ : 'changedtick:' . changedtick

	let lines_cache_key = s:get_lines_cache_key(a:fname)
	let use_cache_entry = has_key(g:ctrlp_buftags, lines_cache_key)
	if use_cache_entry
		let cache_entry = g:ctrlp_buftags[lines_cache_key]
		let use_cache_entry = (cache_entry['change_id'] ==# change_id_val)
			\ && (a:ftype ==# cache_entry['ftype'])
	en

	" MAYBE: use a third variant for the 'change_id' element:
	"  IDEA: 'ftime=nnnn::changedtick=mmmmm' (which has an implied
	"   entry['match_use_bufcontents'] == 1)
	"   NOTE: I'm not sure that works, as the logic to know for sure whether to
	"    set 'match_use_bufcontents' (from s:exectagsonfile()) is different to
	"    the one where we think we might need it (here)
	" when using the results calculated against the original file, only use the
	" existing cache entry if it matches our perception of whether to use the
	" "precise" matching (line numbers, with patterns being merely decorative)
	" or not (patterns, use 's:chknearby()').
	if use_cache_entry && ctags_use_origfile
		let entry_match_use_bufcontents = !!get(cache_entry, 'match_use_bufcontents')
		let use_cache_entry = (
			\	((!file_modified_flag) == entry_match_use_bufcontents)
			\ &&
			\ ((!entry_match_use_bufcontents)
			\  || (get(g:ctrlp_buftags[lines_cache_key], 'changedtick') ==# changedtick))
			\ )
	en

	if use_cache_entry
		let lines = cache_entry['lines']
		let cache_entry['entered_count'] = s:entered_count
	el
		let [data, match_use_bufcontents] =
			\ s:exectagsonfile(a:fname, a:ftype, ctags_use_origfile)
		let [raw, lines] = [split(data, '\n\+'), []]
		" TODO: do this with: filter( map( filter(raw, '!__TAG__ && split() is ok'), 's:parseline(v:val)'), '!empty(v:val)' ) -- leaves 'raw' with what is to be used as 'lines'
		for line in raw
			if line !~# '^!_TAG_' && len(split(line, ';"')) == 2
				let parsed_line = s:parseline(line, match_use_bufcontents)
				if parsed_line != ''
					cal add(lines, parsed_line)
				en
			en
		endfo
		let cache_entry = {
			\ 'change_id': change_id_val,
			\ 'ftype': a:ftype,
			\ 'entered_count': s:entered_count,
			\ 'lines': lines,
			\ }
		if match_use_bufcontents
			cal extend(cache_entry, {
				\ 'match_use_bufcontents': match_use_bufcontents,
				\ 'changedtick': changedtick,
				\ })
		en
		let g:ctrlp_buftags[lines_cache_key] = cache_entry
	en
	" TODO: remove logging from final commit
	cal ctrlp#ev_log_printf(
		\ 's:process(): exiting normally. len(lines)=%d;',
		\	len(lines))
	retu lines
endf

fu! s:parseline(line, match_use_bufcontents)
	let vals = matchlist(a:line,
		\ '\v^([^\t]+)\t(.+)\t[?/]\^?(.{-1,})\$?[?/]\;\"\t(.+)\tline(no)?\:(\d+)')
	if vals == [] | retu '' | en

	let fname = vals[2]
	if exists('s:tempfilenames')
		" getting the default value (used as a key here) could be because there is
		" no mapping from 's:tempfilenames' to an original name:
		" 1. the mapping from a temporary to a real filename has failed;
		" 2. even though this dictionary exists, another function has decided not
		"    to map the file this time (for example, if the file wasn't dirty, we
		"    ran ctags against the original, which would not have an entry as a
		"    key in 's:tempfilenames');
		let fname = get(s:tempfilenames, fname, fname)
	en

	let [bufnr, bufname] = [bufnr('^'.fname.'$'), fnamemodify(fname, ':p:t')]

	let lineno = vals[6]
	" ref: fu! ctrlp#utils#regex_literal2regex_nomagic(str)
	let pattern = a:match_use_bufcontents
		\ ? ctrlp#utils#regex_literal2regex_nomagic(
		\			get(getbufline(bufnr, lineno), 0, ''))
		\ : vals[3]
	" MAYBE: make the "remove leading and trailing spaces" unconditional, so
	" patterns will match more easily (they'll deal with de-indenting better
	" than the previous implementation).
	"  (note: there are other places in this file where this idea is explored
	"  further)
	if a:match_use_bufcontents
		" put the line, as it appears in the file, just making sure that there are
		" no tabs in there (we'll use two spaces for that, to show that those
		" characters are not equivalent to a single space each).
		let pattern = substitute(
			\		substitute(pattern, '\v^\s*(.{-}\S)\s*$', '\1', '')
			\ , '\t', '  ', 'g')
	en

	retu vals[1].'	'.vals[4].'|'.bufnr.':'.bufname.'|'.lineno.'| '.pattern
endf

fu! s:syntax()
	if !ctrlp#nosy()
		cal ctrlp#hicheck('CtrlPTagKind', 'Title')
		cal ctrlp#hicheck('CtrlPBufName', 'Directory')
		cal ctrlp#hicheck('CtrlPTabExtra', 'Comment')
		sy match CtrlPTagKind '\zs[^\t|]\+\ze|\d\+:[^|]\+|\d\+|'
		sy match CtrlPBufName '|\d\+:\zs[^|]\+\ze|\d\+|'
		sy match CtrlPTabExtra '\zs\t.*\ze$' contains=CtrlPBufName,CtrlPTagKind
	en
endf

fu! s:chknearby(pat)
	if match(getline('.'), a:pat) < 0
		let [int, forw, maxl] = [1, 1, line('$')]
		" FIXME: I think this call is missing the 'stopline' parameter
		" MAYBE: the maximum number of lines to consider in the search should not
		" be 'maxl', but rather max([line('$')-line('.'),line('.')], which could
		" save a search "major loop" (2 searches, one with 'forw' and one with
		" '!forw') when line('.') is (roughly?) line('$')/2.
		" TODO: implement a "limit" variable ('s:opts') to minimise the number of
		" searches to be made.  In particular, when using s:linesfrombuffer_flag,
		" this number could be made quite small, as the tags are supposed to
		" match, and not having a match could be considered a bad thing, which
		" could be highlighted by having the cursor on the "wrong" line.
		"  IDEA: use a function like the one I've created to create regexes from
		"  literals, knowing how "magic" the setting has to be ("verymagic" in my
		"  function, IIRC).
		wh !search(a:pat, 'W'.( forw ? '' : 'b' ))
			if !forw
				if int > maxl | brea | en
				let int += int
			en
			let forw = !forw
		endw
	en
endf

fu! s:initonce() abort
	if s:initonce_done | retu | en

	if has('autocmd')
		aug CtrlPAugBufferTag
			au!
			au BufDelete,BufUnload * nested cal s:autocmd_on_bufremove()
		aug END
	en

	let s:initonce_done = 1
endf

" autocmd support {{{2
if has('autocmd')

fu! s:autocmd_on_bufremove()
	" NOTE: interesting expand()-friendly tokens: <afile>, <abuf>
	" * BufDelete: <afile>
	" * BufUnload: <afile>
	" NOTE: as 's:get_lines_cache_key()' might return mangled values for bufnr(expr) or
	" bufname(expr), and we don't want to rely on the specific priority order in
	" which those are given (if there is more than one possibility), then we'll
	" just try to remove the entry more than once, thus allowing
	" 's:get_lines_cache_key()' to return a different value on every subsequent
	" call (the second is the last, currently), therefore yielding a potentially
	" different cache key.
	for i in range(2)
		let cache_key_todel = s:get_lines_cache_key(expand('<afile>'))
		if has_key(g:ctrlp_buftags, cache_key_todel)
			" remove the "tag lines" cache entry
			unl g:ctrlp_buftags[cache_key_todel]
		en
	endfo
endf

en
" Public {{{1
fu! ctrlp#buffertag#init(fname)
	if !s:initonce_done | cal s:initonce() | en
	let bufs = filter(
		\ (exists('s:btmode') && s:btmode)
		\ ? ctrlp#buffers()
		\ : [exists('s:bufname') ? s:bufname : a:fname]
		\ , 's:validfile(v:val)')

	" MAYBE: move this functionality to a new funtion 's:update_invocation_data(bufs)'
	" work out whether to account for this invocation as a distinct one.
	let local_run_id =
		\ join(
		\		sort(
		\			map(copy(bufs), 's:get_lines_cache_key(v:val)')
		\		),
		\		'::sep::'
		\ )
	if s:cache_mru_dupcounts || (local_run_id !=# get(s:, 'local_run_id_last', '::default::'))
		let s:entered_count += 1
	en
	let s:local_run_id_last = local_run_id

	let lines = []
	for each in bufs
		let bname = fnamemodify(each, ':p')
		let tftype = s:get_ctags_ftype('^'.bname.'$')
		cal extend(lines, s:process(bname, tftype))
	endfo
	cal s:syntax()
	cal s:rmtempfiles()
	cal s:update_mru_cache(bufs)
	retu lines
endf

let s:impl_select_usetagutils = 1

if get(s:, 'impl_select_usetagutils')

let s:impl_select_usetagutils_2 = 1

if get(s:, 'impl_select_usetagutils_2')

fu! ctrlp#buffertag#accept(mode, str)
	let log_pref = 'ctrlp#buffertag#accept():'
	"? let except_pref = log_pref

	let vals = matchlist(a:str,
		\ '\v^([^\t]+)\t+[^\t|]+\|(\d+)\:[^\t|]+\|(\d+)\|\s(.+)$')
	let bufnr = str2nr(get(vals, 2))
	if !(bufnr > 0) | retu | en

	let tg = get(vals, 1, '')
	let lineno = str2nr(get(vals, 3, 0))
	let tgline = get(vals, 4, '')

	" prev: " as we know that we've shown the original line *if* the ctags program was
	" prev: " happy to generate a line number as the 'ex' command to find the tag, we
	" prev: " need to make the original buffer line string into a 'nomagic'-compatible
	" prev: " pattern.
	" prev: if lineno > 0
	" prev: 	" prev: let tgline = escape(tgline, '\')
	" prev: 	let tgline = ctrlp#utils#regex_literal2regex_nomagic(tgline)
	" prev: en

	let match_use_bufcontents = 0

	" optionally leave the cursor in the current line: when we know that the
	" tags correspond to the buffer contents
	" (cache_entry['match_use_bufcontents'] is set), there is no point in
	" trying to run the 'ex' command in the 'ctags(5)' file to position the
	" cursor in the line for the selected identifier.
	let lines_cache_key = s:get_lines_cache_key(bufnr)
	if has_key(g:ctrlp_buftags, lines_cache_key)
		let cache_entry = g:ctrlp_buftags[lines_cache_key]
		if get(cache_entry, 'match_use_bufcontents')
					\ && (get(cache_entry, 'changedtick') ==#
					\		ctrlp#utils#getbufvar(bufnr, 'changedtick'))
			let match_use_bufcontents = 1
		en
	en

	" FIXME: remove (testing) {{{
	let tgline_hack_suff = get(g:, 'ev_testing_tgline_suff', '')
	let tgline .= tgline_hack_suff
	" }}}

	let expr_dict = ctrlp#tagutils#tgcmd_searchexprdict_createstd(tgline)

	" TODO: implement a new variable to allow for this sequence of commands:
	"		* if match_use_bufcontents?:
	"			+ start search at the specified 'lineno' (if one exists): this is
	"				going to be a new "set variable" command:
	"				+	'set_search_startpos': (will be ignored in 'post_search_nearby',
	"					as the starting position for that is whichever is the ending
	"					position for the preceding successful command(s));
	"					+ <=0: disable this (this will 'unlet!' the variable inside the
	"						function, so the starting position will be the current position
	"						in that buffer (or something else?));
	"					+ >0: use this line number;
	"					+ list: use (certain elements of?) as a parameter to setpos('.', ...)
	"						+ maybe: ignore the bufnr and possibly others
	"			+ use a new command: 'findtag_searchnearby', so the same internal
	"				function can be used (s:search_nearby_move());
	" prev: let gototag_item_findtagcmd_verb = 'findtag_tagcmd'
	let gototag_item_findtagcmd_verb = s:findtagcmd_verb_def

	" TODO: specify other kwargs, too: 'pos_on_notfound', 'action_on_notfound'
	if 1

	let gototag_item_findtagcmd_issearch = 
		\	ctrlp#tagutils#accept_tag_gototagdata_verbusesdataid(
		\		gototag_item_findtagcmd_verb,
		\		'gtd_dataid_pattern')

	let gototag_item_searchpattern_verb =
		\	( gototag_item_findtagcmd_issearch || (!(lineno > 0)) )
		\	?	gototag_item_findtagcmd_verb
		\	:	'post_search_nearby'

	cal ctrlp#ev_log_printf(
		\	'%s about to call ctrlp#tagutils#accept_tag(). ' .
		\		'mode=%s; name=%s; bufnr=%d; ' .
		\		'tgline=%s; lineno=%d; ' .
		\		'match_use_bufcontents=%d; ' .
		\		'gototag_item_findtagcmd_issearch=%d; ' .
		\		'gototag_item_searchpattern_verb=%s;',
		\	log_pref, string(a:mode), string(tg), bufnr,
		\	string(tgline), lineno,
		\	match_use_bufcontents,
		\	gototag_item_findtagcmd_issearch,
		\	string(gototag_item_searchpattern_verb)
		\	)
	retu ctrlp#tagutils#accept_tag({
		\		'mode': a:mode,
		\		'name': tg,
		\		'bufnr': bufnr,
		\		'gototag_data':
		\			(	match_use_bufcontents
		\				?	[
		\						[ 'set_search_nearby_maxdistance', 0 ],
		\					]
		\				:	[]
		\			)
		\			+
		\			(	(lineno > 0)
		\				?	(	gototag_item_findtagcmd_issearch
		\						?	[
		\								[ 'set_search_startpos', lineno ],
		\							]
		\						:	[
		\								[ 'set_cmd', '' . lineno ],
		\								gototag_item_findtagcmd_verb,
		\								[ 'post_execmd', 'normal! ^' ],
		\							]
		\					)
		\				:	[]
		\			)
		\			+
		\			ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\				expr_dict,
		\				gototag_item_searchpattern_verb,
		\				'tgcmd_exprid_tgpattern_orig')
		\			+
		\			(	match_use_bufcontents
		\				?	[]
		\				:
		\					ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\						expr_dict,
		\						gototag_item_searchpattern_verb,
		\						'tgcmd_exprid_tgpattern_ignws_lead')
		\					+
		\					ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\						expr_dict,
		\						gototag_item_searchpattern_verb,
		\						'tgcmd_exprid_tgpattern_ignws_trail')
		\					+
		\					ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\						expr_dict,
		\						gototag_item_searchpattern_verb,
		\						'tgcmd_exprid_tgpattern_ignws_all')
		\					+
		\					ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\						expr_dict,
		\						gototag_item_searchpattern_verb,
		\						'tgcmd_exprid_tgpattern_substr_anyaround')
		\			)
		\			+
		\			[
		\				[ 'set_cmd', 'normal! zvzz' ],
		\				'post_execmd',
		\			],
		\	})

	elsei 1

	let gototag_item_searchpattern_verb =
		\	( match_use_bufcontents || ( lineno > 0 ) )
		\	?	'post_search_nearby'
		\	:	gototag_item_findtagcmd_verb

	retu ctrlp#tagutils#accept_tag({
		\		'mode': a:mode,
		\		'name': tg,
		\		'bufnr': bufnr,
		\		'gototag_data':
		\			(	(lineno > 0)
		\				?	[
		\						[ 'set_cmd', '' . lineno ],
		\						gototag_item_findtagcmd_verb,
		\						[ 'post_execmd', 'normal! ^' ],
		\					] +
		\					(	match_use_bufcontents
		\						?	[
		\								[ 'set_search_nearby_maxdistance', 0 ],
		\							]
		\						:	[]
		\					)
		\				:	(	match_use_bufcontents
		\						?	ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\								expr_dict,
		\								gototag_item_findtagcmd_verb,
		\								'tgcmd_exprid_tgpattern_orig')
		\						:	[]
		\					)
		\			)
		\			+
		\			(	(!( (lineno > 0) && match_use_bufcontents ))
		\				?
		\					ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\						expr_dict,
		\						gototag_item_searchpattern_verb,
		\						'tgcmd_exprid_tgpattern_orig')
		\					+
		\					ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\						expr_dict,
		\						gototag_item_searchpattern_verb,
		\						'tgcmd_exprid_tgpattern_ignws_lead')
		\					+
		\					ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\						expr_dict,
		\						gototag_item_searchpattern_verb,
		\						'tgcmd_exprid_tgpattern_ignws_trail')
		\				:	[]
		\			)
		\			+
		\			ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\				expr_dict,
		\				gototag_item_searchpattern_verb,
		\				'tgcmd_exprid_tgpattern_ignws_all')
		\			+
		\			ctrlp#tagutils#accept_tag_gototagdata_getelemsfromsrchexprdict(
		\				expr_dict,
		\				gototag_item_searchpattern_verb,
		\				'tgcmd_exprid_tgpattern_substr_anyaround')
		\			+
		\			[
		\				[ 'set_cmd', 'normal! zvzz' ],
		\				'post_execmd',
		\			],
		\	})
	en
endf

el " s:impl_select_usetagutils_2

	" FIXME: continue...
	"  TODO: in ctrlp#tagutils#accept_tag():
	"   TODO: the 'post_search_nearby' should flag whether it has found
	"   something or not, and just execute it once (like the 'findtag_tagcmd'
	"   does)
	"   TODO: when executing 'post_search_nearby', make sure that we save the
	"   position at which the tag has been "found", so we can revert to that
	"   position if the search hasn't worked.
	"   TODO: when executing 'post_search_nearby', try not to have a loop, but
	"   instead be clever about lines that match, so we can work out which one
	"   is the closest one from where the cursor is (/supposed to be).
	"    NOTE: see ':h search()', and think of "distances" to use on each
	"    iteration: maybe something like: 50 lines, 300 lines, 25%, 60%, 100%?
	"    (obviously trimming the ranges that don't make sense/that have been
	"    already searched)
	"   TODO: when processing commands (of what type?), make sure that
	"   'keepjumps' (and whichever other) are all automatically added.
	"   TODO: make sure we save, force setting, and restore: hlsearch, @/, etc.
	"   TODO: support a list of commands to execute ('findtag_execmd', etc.), in
	"   such a way that command prefixes can be added to every list item, if
	"   needed.
	"    TODO: or just save, force set, and restore certain settings.
	"     TODO: make sure that things like 'sandbox' can be done in that way,
	"     too, or just fallback to running every command with a prefix for those
	"     settings that can't be set (and restored) using options (say, for
	"     'sandbox'), and still save-set-restore values for the others (like
	"     'noautocmd', which can be emulated by setting a global option, for
	"     example).
fu! ctrlp#buffertag#accept(mode, str)
	" prev: \ '\v^[^\t]+\t+[^\t|]+\|(\d+)\:[^\t|]+\|(\d+)\|\s(.+)$')
	let vals = matchlist(a:str,
		\ '\v^([^\t]+)\t+[^\t|]+\|(\d+)\:[^\t|]+\|(\d+)\|\s(.+)$')
	" prev: let bufnr = str2nr(get(vals, 1))
	let bufnr = str2nr(get(vals, 2))
	if !(bufnr > 0) | retu | en

	let tg = get(vals, 1, '')
	" prev: let lineno = str2nr(get(vals, 2, 0))
	let lineno = str2nr(get(vals, 3, 0))
	" prev: let tgline = get(vals, 3, '')
	let tgline = get(vals, 4, '')

	let match_use_bufcontents = 0

	" optionally leave the cursor in the current line: when we know that the
	" tags correspond to the buffer contents
	" (cache_entry['match_use_bufcontents'] is set), there is no point in
	" trying to run the 'ex' command in the 'ctags(5)' file to position the
	" cursor in the line for the selected identifier.
	let lines_cache_key = s:get_lines_cache_key(bufnr)
	if has_key(g:ctrlp_buftags, lines_cache_key)
		let cache_entry = g:ctrlp_buftags[lines_cache_key]
		if get(cache_entry, 'match_use_bufcontents')
					\ && (get(cache_entry, 'changedtick') ==#
					\		ctrlp#utils#getbufvar(bufnr, 'changedtick'))
			let match_use_bufcontents = 1
		en
	en

	" If we use 'tgsearchstr' when 'match_use_bufcontents' is true, then we
	" need to be a bit more relaxed with regards to spaces before and after
	" the non-whitespace "middle bit", as that could have been removed in
	" 's:parseline()'.
	let tgsearchstr_pref = '\V\C'

	" TODO: idea: tgsearchstr_meat_orig, tgsearchstr_meat_nows
	"  IDEA: map([['tgsearchstr_meat_orig', []], ['tgsearchstr_meat_nows',
	"  [/*args to substitute to replace leading and trailing whitespaces for the
	"  empty string*/]]]) // include the 'escape()' in the result
	" prev: let tgsearchstr_meat = escape(tgline, '\')
	"? [unfinished] let tgsearch_items_list = map(
	"? [unfinished] 	\		[
	"? [unfinished] 	\			['tgsearchstr_meat_orig', []],
	"? [unfinished] 	\			['tgsearchstr_meat_nows', ['\v^\s*(.{-})\s*$', '\1', '']],
	"? [unfinished] 	\		],
	"? [unfinished] 	\		'empty(v:val[1]) ? [v:val[0], tgline] : ' .
	"? [unfinished] 	\			'[v:val[0], call("substitute", [tgline] + v:val[1])]'
	"? [unfinished] 	\		// ... 'escape((empty(v:val[1]) ? v:val....))'
	"? [unfinished] 	\	)
	"- let tgsearch_flavours_dict = map(
	"- 	\	map(
	"- 	\		{
	"- 	\			'tgsearchstr_meat_orig': [],
	"- 	\			'tgsearchstr_meat_nows': ['\v^\s*(.{-})\s*$', '\1', ''],
	"- 	\		},
	"- 	\		'empty(v:val) ? tgline : ' .
	"- 	\			'call("substitute", [tgline] + v:val)'),
	"- 	\	'escape(v:val, ''\'')'
	"- 	\	)
	" TODO: add other "flavours": .._nows_lead, ..._nows_trail
	" TODO: add new "regex" variables and add them when !match_use_bufcontents
	"  (see below), so we try:
	"  * exact (exact match on the leading and trailing spaces);
	"  * ignore leading spaces (but trailing spaces are the same);
	"  * ignore trailing spaces (but leading are the same);
	"  * ignore all whitespaces (but the only thing around it should be
	"			whitespaces);
	"	 * ignore anything around the nows string (this is the "relaxed");
	"	IDEA: create a dictionary based on the "tagcmd" ('tgline' here) with every
	"	one of the alternatives above, allowing for:
	"		* use of 'nomagic', as per the 'vi(1)' ':h tags-file-format';
	"			MAYBE: always generate these 'nomagic' strings everywhere in that
	"			function;
	"		* create elements that are either the patterns, or the commands (for
	"			now, only the '/' is added at the beginning of each of the generated
	"			patterns);
	"		* use these entries from both 'ctrlp/tag.vim' and 'ctrlp/buffertag.vim'
	"			to specify the values for each of the search patterns.
	"			NOTE: the 'post_search_nearby' now allows for an optional search
	"			string, so that we could 'map()' every entry returned in the
	"			dictionary generated by that function into values to be passed to
	"			ctrlp#tagutils#accept_tag().
	"			IDEA: so we can transform the dictionary values using 'map()':
	"				map(['tgsearchstr_orig', 'tgsearchstr_ignore_leading_spaces', ...],
	"					'[ ''post_search_nearby'', generated_dict[v:val] ]')
	let tgsearch_flavours_dict = map(
		\	{
		\		'tgsearchstr_meat_orig': 0,
		\		'tgsearchstr_meat_nows': ['\v^\s*(.{-})\s*$', '\1', ''],
		\	},
		\	'empty(v:val) ? tgline : ' .
		\		'call("substitute", [tgline] + v:val)')

	" prev: let tgsearchstr_skipws = match_use_bufcontents ? '\s\*' : ''
	let tgsearchstr_skipws = '\s\*'

	" prev: " prev: let tgsearchstr =
	" prev: " prev: 	\	tgsearchstr_pref .
	" prev: " prev: 	\	'\^' .
	" prev: " prev: 	\	tgsearchstr_skipws .
	" prev: " prev: 	\	tgsearchstr_meat .
	" prev: " prev: 	\	tgsearchstr_skipws .
	" prev: " prev: 	\	'\$'
	" prev: let tgsearchstr_final_ignorewhitespace =
	" prev: 	\	tgsearchstr_pref .
	" prev: 	\	'\^' .
	" prev: 	\	tgsearchstr_skipws .
	" prev: 	\	tgsearchstr_meat .
	" prev: 	\	tgsearchstr_skipws .
	" prev: 	\	'\$'
	" prev: let tgsearchstr_final_exact =
	" prev: 	\	tgsearchstr_pref .
	" prev: 	\	'\^' .
	" prev: 	\	tgsearchstr_meat .
	" prev: 	\	'\$'
	" prev: let tgsearchstr_final_relaxed =
	" prev: 	\	tgsearchstr_pref .
	" prev: 	\	tgsearchstr_meat
	let tgsearchstr_final_ignorewhitespace =
		\	tgsearchstr_pref .
		\	'\^' .
		\	tgsearchstr_skipws .
		\	tgsearch_flavours_dict['tgsearchstr_meat_nows'] .
		\	tgsearchstr_skipws .
		\	'\$'
	let tgsearchstr_final_exact =
		\	tgsearchstr_pref .
		\	'\^' .
		\	tgsearch_flavours_dict['tgsearchstr_meat_orig'] .
		\	'\$'
	let tgsearchstr_final_relaxed =
		\	tgsearchstr_pref .
		\	tgsearch_flavours_dict['tgsearchstr_meat_nows'] .
		\	''

	let tgsearch_cmd_pref = '/'

	" prev: let tgsearch_cmd = tgsearch_cmd_pref . tgsearchstr

	" prev: \			(	( (lineno > 0) && match_use_bufcontents )
	" prev: \				?  [
	" prev: \						[ 'set_cmd', lineno ],
	" prev: \						'findtag_tagcmd',
	" prev: \					] +
	" prev: \				:	[]
	" prev: \			) +
	"
	" prev: \			[
	" prev: \				[ 'set_cmd',
	" prev: \					(	( lineno > 0 )
	" prev: \						?	lineno
	" prev: \						:	tgsearch_cmd_pref .
	" prev: \							(	match_use_bufcontents
	" prev: \								?	tgsearchstr_final_ignorewhitespace
	" prev: \								:	tgsearchstr_final_exact
	" prev: \							)
	" prev: \					)
	" prev: \				],
	" prev: \				'findtag_tagcmd',
	" prev: \			] +
	" TODO: specify other kwargs, too: 'pos_on_notfound', 'action_on_notfound'
	retu ctrlp#tagutils#accept_tag({
		\		'mode': a:mode,
		\		'name': tg,
		\		'bufnr': bufnr,
		\		'gototag_data':
		\			(	(lineno > 0)
		\				?	[
		\						[ 'set_cmd', '' . lineno ],
		\						'findtag_tagcmd',
		\					]
		\				:	[]
		\			) +
		\			(	(!match_use_bufcontents)
		\				?	[
		\						[ 'set_cmd',
		\							tgsearch_cmd_pref .
		\								tgsearchstr_final_exact ],
		\						'findtag_tagcmd',
		\					]
		\				:	[]
		\			) +
		\			[
		\				[ 'set_cmd',
		\					tgsearch_cmd_pref .
		\						tgsearchstr_final_ignorewhitespace ],
		\				'findtag_tagcmd',
		\			] +
		\			(	(!match_use_bufcontents)
		\				?	[
		\						[ 'set_searchstring',
		\							tgsearchstr_final_exact ],
		\						'post_search_nearby',
		\						[ 'set_searchstring',
		\							tgsearchstr_final_ignorewhitespace ],
		\						'post_search_nearby',
		\						[ 'set_searchstring',
		\							tgsearchstr_final_relaxed ],
		\						'post_search_nearby',
		\					]
		\				:	[]
		\			) +
		\			[
		\				[ 'set_cmd', 'normal! zvzz' ],
		\				'post_execmd',
		\			],
		\	})

endf

en " s:impl_select_usetagutils_2

el " s:impl_select_usetagutils

fu! ctrlp#buffertag#accept(mode, str)
	let vals = matchlist(a:str,
		\ '\v^[^\t]+\t+[^\t|]+\|(\d+)\:[^\t|]+\|(\d+)\|\s(.+)$')
	let bufnr = str2nr(get(vals, 1))
	if bufnr
		cal ctrlp#acceptfile(a:mode, bufnr)

		let lineno = str2nr(get(vals, 2, 0))
		let do_chknearby = 1

		if (lineno > 0)
			" NOTE: we don't check that 'lineno <= line('$')', as if 'lineno' is too
			" big the current buffer contents, the '{too_big}G' command will still
			" position the cursor in the last line, which is the closest we can be
			" to an unknown position that is likely to be near the bottom of the
			" file/buffer now.
			exe 'norm!' lineno.'G'

			" optionally leave the cursor in the current line: when we know that the
			" tags correspond to the buffer contents
			" (cache_entry['match_use_bufcontents'] is set), there is no point in
			" trying to run the 'ex' command in the 'ctags(5)' file to position the
			" cursor in the line for the selected identifier.
			let lines_cache_key = s:get_lines_cache_key()
			if has_key(g:ctrlp_buftags, lines_cache_key)
				let cache_entry = g:ctrlp_buftags[lines_cache_key]
				if get(cache_entry, 'match_use_bufcontents')
							\ && (get(cache_entry, 'changedtick') ==# get(b:, 'changedtick'))
					let do_chknearby = 0
				en
			en
		en

		" NOTE: the string '\V\C' (and the default value ('') appended to it)
		" matches ('search()') on every non-empty line.
		" TODO: let s:chknearby() work out a series of patterns instead of
		" specifying a prefix and/or suffix to the original pattern here.
		if do_chknearby | cal s:chknearby('\V\C'.get(vals, 3, '')) | en

		sil! norm! zvzz
	en
endf

en " s:impl_select_usetagutils

fu! ctrlp#buffertag#cmd(mode, ...)
	let s:btmode = a:mode
	if a:0 && !empty(a:1)
		let s:btmode = 0
		let bname = a:1 =~# '^%$\|^#\d*$' ? expand(a:1) : a:1
		let s:bufname = fnamemodify(bname, ':p')
	en
	retu s:id
endf

fu! ctrlp#buffertag#exit()
	unl! s:btmode s:bufname
endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
