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
" for now, only the first component in a multi-component value is considered.
fu! s:get_ctags_ftype(fname)
	retu get(split(getbufvar(a:fname, '&filetype'), '\.'), 0, '')
endf
" optional args: [ftype]
"  ftype:
"   default: calculated/retrieved from fname/the buffer corresponding to
"            fname.
" orig: fu! s:validfile(fname, ftype)
fu! s:validfile(fname, ...)
	if empty(a:fname) | retu 0 | en
	" prev: let ftype = a:0 > 0 ? a:1 : getbufvar(a:fname, '&filetype')
	let ftype = a:0 > 0 ? a:1 : s:get_ctags_ftype(a:fname)
	if empty(ftype) || index(keys(s:types), ftype) < 0 | retu 0 | en
	" allow files to be tagged from buffers when they're not readable.
	" prev: " removed: \ || filereadable(a:fname)
	" prev: if ctrlp#utils#fname_is_virtual(a:fname)
	" prev: 	\ || s:linesfrombuffer_flag
	" prev: 	\ | retu 1 | en
	retu 1
	" prev: retu 0
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

fu! s:exectagsonfile(fname, ftype, ctags_use_origfile)
	let [ags, ft] = ['-f - --sort=no --excmd=pattern --fields=nKs --extra= --file-scope=yes ', a:ftype]
	if type(s:types[ft]) == 1
		let ags .= s:types[ft]
		let bin = s:bin
	elsei type(s:types[ft]) == 4
		let ags = s:types[ft]['args']
		let bin = expand(s:types[ft]['bin'], 1)
	en
	if empty(bin) | retu '' | en
	" prev: " Only use a temporary file when that feature is enabled and it's necessary.
	" prev: " This includes the cases where the user does not specifically want to use
	" prev: " the buffer contents, and either:
	" prev: " * the file is not a physical one (so this script will prioritise using
	" prev: "   the buffer contents to avoid potentially slow and/or unreliable I/O);
	" prev: " * the file is not readable;
	" prev: if (s:linesfrombuffer_flag && getbufvar(a:fname, '&modified'))
	" prev: 			\ || ctrlp#utils#fname_is_virtual(a:fname)
	" prev: 			\ || (!filereadable(a:fname))
	" prev: 	let fname_ctags = s:tmpfilenamefor(a:fname, a:ftype)
	" prev: 	" forcibly write the lines to that file, and use the original file as a
	" prev: 	" fallback if that didn't work.
	" prev: 	" getline(1, '$')
	" prev: 	" the ':sil[ent]' prefix avoids error messages being logged/written, but
	" prev: 	" we can still react to errors by storing the return value from
	" prev: 	" 'writefile()'.
	" prev: 	"-? (empty contents) sil let rc = writefile(getline(1, '$'), fname_ctags)
	" prev: 	sil let rc = writefile(getbufline(a:fname, 1, '$'), fname_ctags)
	" prev: 	if rc < 0
	" prev: 		let fname_ctags = a:fname
	" prev: 	en
	" prev: el
	" prev: 	let fname_ctags = a:fname
	" prev: en
	if a:ctags_use_origfile
		let fname_ctags = a:fname
	el
		let fname_ctags = s:tmpfilenamefor(a:fname, a:ftype)
		" forcibly write the lines to that file, and use the original file as a
		" fallback if that didn't work.
		" NOTE: the ':sil[ent]' prefix avoids error messages being logged/written,
		" but we can still react to errors by storing the return value from
		" 'writefile()'.
		if !empty(fname_ctags)
			"-? (empty contents) sil let rc = writefile(getline(1, '$'), fname_ctags)
			sil let rc = writefile(getbufline(a:fname, 1, '$'), fname_ctags)
			" MAYBE: report error?
			if rc < 0 | let fname_ctags = '' | en
		en
			" prev: " prev: " prev: if ctrlp#utils#fname_is_virtual(a:fname)
			" prev: " prev: " prev: 	\ || (!filereadable(a:fname))
			" prev: " prev: " prev: 	retu ''
			" prev: " prev: " prev: en
			" prev: " prev: " prev: let fname_ctags = a:fname
			" prev: " prev: if (!ctrlp#utils#fname_is_virtual(a:fname))
			" prev: " prev: 	\ && filereadable(a:fname)
			" prev: " prev: 	let fname_ctags = a:fname
			" prev: " prev: el
			" prev: " prev: 	retu ''
			" prev: " prev: en
			" prev: if !(
			" prev: 	\ (!ctrlp#utils#fname_is_virtual(a:fname))
			" prev: 	\ && filereadable(a:fname))
			" prev: 	retu ''
			" prev: en
			" prev: let fname_ctags = a:fname
		if empty(fname_ctags)
			if !(
				\ (!ctrlp#utils#fname_is_virtual(a:fname))
				\ && filereadable(a:fname))
				retu ''
			en
			let fname_ctags = a:fname
		en
	en

	let cmd = s:esctagscmd(bin, ags, fname_ctags)
	if empty(cmd) | retu '' | en
	let output = s:exectags(cmd)
	if v:shell_error || output =~ 'Warning: cannot open' | retu '' | en
	retu output
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
fu! s:tmpfilenamefor(fname, ftype)
	if !exists('s:tempfilenames')
		" this name does not have a relevant name/extension, but we'll use it as
		" the basis for our generated filenames
		let s:tempfile_main = tempname()
		" prev: let s:tempfilenames = [s:tempfile_main]
		let s:tempfilenames = {s:tempfile_main: ''}
	en
	let fname = fnamemodify(bufname(a:fname), ':p')
	let tempfname = s:tempfile_main . '-' . fnamemodify(fname, ':t')
	" NOTE: we don't check whether this file exists or not, as we might be using
	" two files from different directories named the same way, and also we don't
	" want to rule out calling this function twice for the same file at
	" different points in the plugin execution.
	let s:tempfilenames[tempfname] = fname
	return tempfname
endf

fu! s:process(fname, ftype)
	" NOTE: the only caller to this function now makes sure that a:fname is
	" always a 's:validfile()', but this call is not strictly guaranteed (at the
	" moment) to be equivalent to the one made when filtering the buffers list
	" at the beginning.
	if !s:validfile(a:fname, a:ftype) | retu [] | endif

	" prev: let ctags_use_origfile = !(
	" prev: 	\ (s:linesfrombuffer_flag && getbufvar(a:fname, '&modified'))
	" prev: 	\ || ctrlp#utils#fname_is_virtual(a:fname)
	" prev: 	\ || (!filereadable(a:fname)))
	let ctags_use_origfile =
		\ (!s:linesfrombuffer_flag || !getbufvar(a:fname, '&modified'))
		\ && !ctrlp#utils#fname_is_virtual(a:fname)
		\ && filereadable(a:fname)

	" done: use 'b:changedtick' instead of 'ftime', as line numbers can become
	" invalid when the file has not been saved.
	"  NOTE: a:fname has already got the canonical buffer/file name
	"  NOTE: this check '>=' seems to be wrong, as we'd only want the line numbers to match, for example.
	" prev: " fixme: implement s:getbufvar()
	" NOTE: if the buffer variable does not exist (but *this* variable is
	" guaranteed to exist), then the value would be '' (no error).
	" done: make sure the 'change_id_val' has some sort of "key" so that we can
	" identify change: for example, if for whatever reason a previous cache
	" entry had to use the buffer contents instead of the file (even though
	" 'g:ctrlp_buftag_linesfrombuffer' ('s:linesfrombuffer_flag') might be
	" unset), then a later 's:process()' call on the same buffer/file would then
	" be allowed to use the original file (for example, filereadable() on the
	" file now returned true), and rightly detect that a new ctags run should be
	" made.
	" prev: let change_id_val = s:linesfrombuffer_flag ? getbufvar(a:fname, 'changedtick') : getftime(a:fname)
	let change_id_val = ctags_use_origfile
		\ ? 'ftime:' . getftime(a:fname)
		\ : 'changedtick:' . getbufvar(a:fname, 'changedtick')
	if has_key(g:ctrlp_buftags, a:fname)
		\ && g:ctrlp_buftags[a:fname]['change_id'] == change_id_val
		let lines = g:ctrlp_buftags[a:fname]['lines']
	el
		" done: move the condition inside s:exectagsonfile() into this function
		" and store its result in l:ctags_use_origfile, which should be then
		" passed as an argument to an extended version of s:exectagsonfile() (so
		" the same 'if' can be used, albeit using the parameter as its expression,
		" instead of the expression that has been moved here).
		let data = s:exectagsonfile(a:fname, a:ftype, ctags_use_origfile)
		let [raw, lines] = [split(data, '\n\+'), []]
		for line in raw
			if line !~# '^!_TAG_' && len(split(line, ';"')) == 2
				let parsed_line = s:parseline(line)
				if parsed_line != ''
					cal add(lines, parsed_line)
				en
			en
		endfo
		let cache = { a:fname : { 'change_id': change_id_val, 'lines': lines } }
		cal extend(g:ctrlp_buftags, cache)
	en
	retu lines
endf

fu! s:parseline(line)
	let vals = matchlist(a:line,
		\ '\v^([^\t]+)\t(.+)\t[?/]\^?(.{-1,})\$?[?/]\;\"\t(.+)\tline(no)?\:(\d+)')
	if vals == [] | retu '' | en

	" prev: let fname_ctags = vals[2]
	let fname = vals[2]
	" prev: if s:linesfrombuffer_flag
	if exists('s:tempfilenames')
		" getting the default input (used as a key here) could be because there is
		" no mapping from 's:tempfilenames' to an original name:
		" 1. the mapping from a temporary to a real filename has failed;
		" 2. even though this dictionary exists, another function has decided not
		"    to map the file this time (for example, if the file wasn't dirty, we
		"    ran ctags against the original, which would not have an entry as a
		"    key in 's:tempfilenames');
		" prev: let fname = get(s:tempfilenames, fname_ctags, fname_ctags)
		let fname = get(s:tempfilenames, fname, fname)
	en

	let [bufnr, bufname] = [bufnr('^'.fname.'$'), fnamemodify(fname, ':p:t')]
	retu vals[1].'	'.vals[4].'|'.bufnr.':'.bufname.'|'.vals[6].'| '.vals[3]
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
	" done: add support for s:linesfrombuffer_flag
	" prev: " orig: \ ? filter(ctrlp#buffers(), 'filereadable(v:val)')
	" prev: let bufs = exists('s:btmode') && s:btmode
	" prev: 	\ ? filter(ctrlp#buffers(), 's:validfile(v:val)')
	" prev: 	\ : [exists('s:bufname') ? s:bufname : a:fname]
	let bufs = filter(
		\ (exists('s:btmode') && s:btmode)
		\ ? ctrlp#buffers()
		\ : [exists('s:bufname') ? s:bufname : a:fname]
		\ , 's:validfile(v:val)')
	let lines = []
	for each in bufs
		let bname = fnamemodify(each, ':p')
		" done: move this to a separate function, and use that from 's:validfile()'
		" orig: let tftype = get(split(getbufvar('^'.bname.'$', '&ft'), '\.'), 0, '')
		let tftype = s:get_ctags_ftype('^'.bname.'$')
		cal extend(lines, s:process(bname, tftype))
	endfo
	cal s:syntax()
	retu lines
endf

fu! ctrlp#buffertag#accept(mode, str)
	let vals = matchlist(a:str,
		\ '\v^[^\t]+\t+[^\t|]+\|(\d+)\:[^\t|]+\|(\d+)\|\s(.+)$')
	let bufnr = str2nr(get(vals, 1))
	if bufnr
		cal ctrlp#acceptfile(a:mode, bufnr)
		exe 'norm!' str2nr(get(vals, 2, line('.'))).'G'
		cal s:chknearby('\V\C'.get(vals, 3, ''))
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
	" prev: for fname in get(s:, 'tempfilenames', [])
	" prev: 	" MAYBE: report error in removing the temporary file(s) ('delete()' return
	" prev: 	" value).
	" prev: 	cal delete(fname)
	" prev: endfo
	let tempfnames = keys(get(s:, 'tempfilenames', {}))
	" delete the main file (if that was set) last, to help other vim instances
	" to not create files based on the same "base" name.
	if !empty(get(s:, 'tempfile_main'))
		cal filter(tempfnames, 'v:val !=# s:tempfile_main')
		cal add(tempfnames, s:tempfile_main)
	en
	for fname in tempfnames
		" MAYBE: report error in removing the temporary file(s) ('delete()' return
		" value).
		cal delete(fname)
	endfo
	unl! s:tempfilenames s:tempfile_main
endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
