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

" TODO: set default for s:cache_mru_maxage to 10
let [s:pref, s:opts] = ['g:ctrlp_buftag_', {
	\ 'systemenc': ['s:enc', &enc],
	\ 'ctags_bin': ['s:bin', ''],
	\ 'types': ['s:usr_types', {}],
	\ 'linesfrombuffer': ['s:linesfrombuffer_flag', 1],
	\ 'cache_mru_maxage': ['s:cache_mru_maxage', 2],
	\ 'cache_mru_dupcounts': ['s:cache_mru_dupcounts', 0],
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
" TODO: make this function use 'keys(s:types)' as a source to filter the
" candidate values for the return value.
"  IDEA: initially, individual components are considered, left-to-right
"   (so, 'c.doxygen' will try 'c' first, then 'doxygen', which could be parsed
"   separately of the main type was not supported).
"   IDEA: have the non-main types supported optionally through a new entry in
"   's:opts'.
" IDEA: support the 'filetype' override for the 'tagbar' plugin (there's a
" buffer-local variable for this, IIRC).
" for now, only the first component in a multi-component value is considered.
fu! s:get_ctags_ftype(fname)
	retu get(split(getbufvar(a:fname, '&filetype'), '\.'), 0, '')
endf

" optional args: [ftype]
"  ftype:
"   default: calculated/retrieved from fname/the buffer corresponding to
"            fname.
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
	if !exists('s:tempfiles_base')
		" find a temporary file/dir that has not yet been created by other
		" scripts.
		" LATER: make sure these checks (/'for' loop) are necessary
		for i in range(5)
			let fname_now = tempname()
			if empty(glob(fname_now))
				" check if the base_file/directory could be created
				if s:tempfiles_base_isdir
					try
						" NOTE: permissions set to make this only readable by the current
						" process effective user.
						" NOTE: throws an exception on failure
						cal mkdir(fname_now, '', 0700)
					cat | con | endt
				el
					" create an empty(-ish) file
					sil if writefile([], fname_now, 'b') != 0 | con | en
				en
				let s:tempfiles_base = fname_now
				break
			en
		endfo
		if !exists('s:tempfiles_base')
			retu ''
		en
	en
	if !exists('s:tempfilenames')
		let s:tempfilenames = {}
	en
	let fname = fnamemodify(bufname(a:fname), ':p')
	let tempfname = (
		\ s:tempfiles_base .
		\ (s:tempfiles_base_isdir ? '/' : '-' ) .
		\ fnamemodify(fname, ':t'))
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
	let tempfnames = keys(get(s:, 'tempfilenames', {}))
	let tempfiles_base = get(s:, 'tempfiles_base')
	" delete the main file (if that was set) last, to help other vim instances
	" to not create files based on the same "base" name.
	if (!empty(tempfiles_base)) && (!s:tempfiles_base_isdir)
		cal add(tempfnames, tempfiles_base)
	en
	for fname in tempfnames
		" MAYBE: report error in removing the temporary file(s) ('delete()' return
		" value) (but check that the file existed before trying to call 'delete()'
		" to avoid reporting an error that is not necessarily I/O related, as an
		" entry in a dictionary pointing to a file that's not there in the first
		" place might not be strictly an I/O error at this point).
		"  IDEA: for fname in filter(tempfnames, '!empty(glob(v:val))')
		"   MAYBE: or even ...filter(copy(tempfnames), ...)
		cal delete(fname)
	endfo
	unl tempfnames

	" remove the base directory, if necessary
	if (!empty(tempfiles_base)) && s:tempfiles_base_isdir
		\ && isdirectory(tempfiles_base)
		" MAYBE: report error
		" NOTE: for now, we ignore the return value (this should not fail)
		cal ctrlp#utils#remove_directory(tempfiles_base)
	en
	unl! s:tempfilenames s:tempfiles_base
endf

" optional args:
"  fname: usually a value retrieved through 'bufname()'.
"   default: bufname('%')
fu! s:get_lines_cache_key(...) abort
	" NOTE: we're using 'bufnr()' now, as those can change for files that have
	" been ':bwipe'd, for example, and we don't want to be too clever about
	" caching previous file contents when we're really keeping buffer-related
	" lines here.
	" NOTE: it's possible that this is a pre-existing bug, so this might go in a
	" different branch (the code using this function should be taken as well, at
	" least minimally, to avoid propagating the decision as to what is the
	" actual key calculation, and keep it in a single place).
	let bname = fnamemodify(a:0 ? a:1 : bufname('%'), ':p')
	let bufnr = bufnr(bname)
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
		" prev: let entered_count_todel_max = max([0, s:entered_count - s:cache_mru_maxage])
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
					" prev: let cache_keys_todel =
					" prev: 	\ filter(
					" prev: 	\   cache_keys_todel,
					" prev: 	\		'!has_key(cache_keys_seen, v:val)')
					" prev: for cache_key_todel in cache_keys_todel
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
	let changedtick = getbufvar(a:fname, 'changedtick')
	let change_id_val = ctags_use_origfile
		\ ? 'ftime:' . getftime(a:fname)
		\ : 'changedtick:' . changedtick

	let lines_cache_key = s:get_lines_cache_key(a:fname)
	let use_cache_entry = has_key(g:ctrlp_buftags, lines_cache_key)
	if use_cache_entry
		let cache_entry = g:ctrlp_buftags[lines_cache_key]
		let use_cache_entry = (cache_entry['change_id'] == change_id_val)
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

	"-? if has_key(g:ctrlp_buftags, lines_cache_key)
	"-? 	\ && g:ctrlp_buftags[lines_cache_key]['change_id'] == change_id_val
	"-? 	\ && ((!ctags_use_origfile)
	"-? 	\     || (!get(g:ctrlp_buftags[lines_cache_key], 'match_use_bufcontents'))
	"-? 	\     || (get(g:ctrlp_buftags[lines_cache_key], 'changedtick') ==# changedtick))
	if use_cache_entry
		" prev: let cache_entry = g:ctrlp_buftags[lines_cache_key]
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
		" TODO: add an autocmd to get rid of the cache entry for the buffer being
		" ':bwipeout'-ed.
		let cache_entry = {
			\ 'change_id': change_id_val,
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
	let pattern = a:match_use_bufcontents
		\ ? get(getbufline(bufnr, lineno), 0, '')
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
" Public {{{1
fu! ctrlp#buffertag#init(fname)
	let bufs = filter(
		\ (exists('s:btmode') && s:btmode)
		\ ? ctrlp#buffers()
		\ : [exists('s:bufname') ? s:bufname : a:fname]
		\ , 's:validfile(v:val)')

	" prev: " TODO: (optionally) only consider this run to count if it's different to
	" prev: "  the last one ('s:cache_mru_dupcounts', see marker o)
	" prev: "  IDEA: let run_id = join(sort(copy(bufs)), '::sep::')
	" prev: "   MAYBE: don't use the 'bufs' list itself, but rather either the
	" prev: "    ctrlp#buffers('id') value, or the cache keys (see below), or...?
	" prev: "   ref: (s:update_mru_cache()) let cache_keys_now = map(copy(a:bufs), 's:get_lines_cache_key(v:val)')
	" prev: "   IDEA: maybe pass those keys instead of the 'bufs' list? or is that too
	" prev: "   prescriptive/"white box-ey"?
	" prev: "  IDEA: if run_id !=# s:run_id_last | let s:run_id_last = run_id | let s:entered_count += 1 | en
	" prev: "
	" prev: "?  \			map(copy(bufs), 'bufnr(v:val) > 0 ? ''bufnr:'' . bufnr(v:val) : v:val')
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
