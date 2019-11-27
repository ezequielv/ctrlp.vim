" =============================================================================
" File:          autoload/ctrlp/tmpfm.vim
" Description:   Temporary Files Manager
" Author:        Ezequiel Valenzuela <github.com/ezequielv>
" =============================================================================

" Global Settings {{{

if get(g:, 'ctrlp_tmpfm_loaded', 0)
	finish
en
let g:ctrlp_tmpfm_loaded = 1

" }}}

" Initialization {{{

" see ':help mkdir()'
let s:tempfiles_base_isdir = exists('*mkdir') && ctrlp#utils#can_remove_directories()

" }}}

" Internals {{{

" prev: let s:typeid_num = type(0)
" prev: let s:typeid_str = type('')

" optional args:
" * components_are_directories (int (bool), optional): if specified, it forces
"   the components to be treated as directories (!= 0) or filename parts (==
"   0).
"   if unspecified, it uses 's:tempfiles_base_isdir'.
fu! s:join_tmpfname_comps(fname_comps, ...) abort
	" prev: let sep = get(a:000, 0, s:tempfiles_base_isdir) ? '/' : '-'
	let sep = (a:0 ? a:1 : s:tempfiles_base_isdir) ? '/' : '-'
	let fname = simplify(join(filter(copy(a:fname_comps), '!empty(v:val)'), sep))
	retu fname
endf

fu! s:init_tmpfiles_vars() abort
	let except_pref = 's:init_tmpfiles_vars():'
	" TODO: rename s:tempfiles_base -> s:tmpfiles_basepath
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
					" create an empty(-ish) file to mark this "potential tmpfile name"
					" as taken/in use.
					sil if writefile([], fname_now, 'b') != 0 | con | en
				en
				let s:tempfiles_base = fname_now
				break
			en
		endfo
		if !exists('s:tempfiles_base')
			" prev: retu ''
			throw printf(
				\	'%s could not find a suitable temporary filename to use as a base',
				\	except_pref)
		en
	en
	if !exists('s:tmpfiles_dict') | let s:tmpfiles_dict = {} | en
endf

fu! s:get_clientkey_for(clientid) abort
	" TODO: improve implementation
	" IDEA: if it's a number, then create an entry based on the g:ctrlp_ext_vars
	" (or a dict constructed from it, keyed on the id? (or is that just the
	" index into this array?))
	" prev: let clientid_type = type(a:clientid)
	" prev: if clientid_type == s:typeid_num | retu ... ? | en
	" force to string (numbers and strings allowed)
	" MAYBE: LATER: a:clientid is a string, we need to make sure that it won't
	" contain pathname/filename_component separators (which should be stored in
	" variable(s) in this file).
	let clientkey = a:clientid . ''
	if empty(clientkey)
		th printf(
			\	's:get_clientkey_for(): cannot calculate clientkey. clientid=%s',
			\	string(a:clientid))
	en
	retu clientkey
endf

" NOTE: the filename returned by this function is not guaranteed to be
" previously unused (within the current ctrlp "session").
" NOTE: I/O errors will (should) raise exceptions, and the data structures
" should still hold their invariants.
fu! ctrlp#tmpfm#get_tmpfilename_for(clientid, fname) abort
	" throws if there was something wrong
	let clientkey = s:get_clientkey_for(a:clientid)
	if !exists('s:tmpfiles_dict') | cal s:init_tmpfiles_vars() | en
	let client_tmpfiles_dict = get(s:tmpfiles_dict, clientkey)
	if empty(client_tmpfiles_dict)
		unl client_tmpfiles_dict
		" NOTE: for now, uses the unmodified 'clientkey' as a file/dir component.
		let basepath = clientkey
		if s:tempfiles_base_isdir
			" XREF: ctrlp#tmpfm#cleanup_for(): identical calculation.
			let basepath_full = s:join_tmpfname_comps([s:tempfiles_base, basepath], !0)
			" try to create it. if it fails, nothing else is recorded, and we won't
			" be "leaking" a file/directory anywhere.
			cal ctrlp#utils#mkdir(basepath_full, 0)
		en
		let client_tmpfiles_dict = {
			\		'basepath': basepath,
			\		'fnames_dict': {},
			\	}
		" commit it to the top-level dictionary.
		let s:tmpfiles_dict[clientkey] = client_tmpfiles_dict
	en
	let fnames_dict = client_tmpfiles_dict['fnames_dict']
	let fname_key = fnamemodify(a:fname, '%:t')
	if !has_key(fnames_dict, fname_key)
		" for now, we store the fully resolved filename, but we could instead/also
		" store the last "original a:fname" value in this dictionary, and always
		" return a calculated value, so we could also be queried for which input
		" last resulted in a particular temporary filename.
		let fname_full = s:join_tmpfname_comps(
			\	[s:tempfiles_base, client_tmpfiles_dict['basepath'], fname_key])
		let fnames_dict[fname_key] = fname_full
	en
	retu fnames_dict[fname_key]
endf

" normally, this function would not be called from other modules, unless we're
" worried that a plugin is consuming too many resources in terms of temporary
" files.
fu! ctrlp#tmpfm#cleanup_for(clientid) abort
	if !exists('s:tmpfiles_dict') | retu 0 | en
	" throws if there was something wrong
	let clientkey = s:get_clientkey_for(a:clientid)
	let client_tmpfiles_dict = get(s:tmpfiles_dict, clientkey)
	if empty(client_tmpfiles_dict) | retu 0 | en

	let except_pref = 'ctrlp#tmpfm#cleanup_for():'
	let [fnames_processed_dict, fnames_failed_dict] = [{}, {}]

	try
		let fnames_dict = client_tmpfiles_dict['fnames_dict']
		for fname_now in values(fnames_dict)
			if has_key(fnames_processed_dict, fname_now) | con | en
			let fnames_processed_dict[fname_now] = 1
			" cheap check to see whether this file exists in the file system.
			if !empty(glob(fname_now))
				try
					let sucflag = !delete(fname_now)
				cat | let sucflag = 0
				endt
				if !sucflag | let fnames_failed_dict[fname_now] = 1 | en
			en
		endfo

		let basepath = get(client_tmpfiles_dict, 'basepath')
		if !empty(basepath) && s:tempfiles_base_isdir
			" XREF: ctrlp#tmpfm#cleanup_for(): identical calculation.
			let basepath_full = s:join_tmpfname_comps([s:tempfiles_base, basepath], !0)
			" try to create it. if it fails, nothing else is recorded, and we won't
			" be "leaking" a file/directory anywhere.
			if ctrlp#utils#remove_directory(basepath_full)
				let fnames_failed_dict[basepath_full] = 1
			en
		en
		cal remove(s:tmpfiles_dict, clientkey)

	fina
		" MAYBE: report errors (!empty(fnames_failed_dict))
		" propagate errors once we've attempted to remove as many files as possible
		" (instead of bailing out on the first failure).
		if empty(v:exception) && !empty(fnames_failed_dict)
			th printf(
				\	'%s removing files/dir for clientid %s: %s',
				\ except_pref, string(a:clientid), string(sort(keys(fnames_failed_dict))))
		en
	endt

	retu !0
endf

" cleans up all the temporary files for every 'clientid' for which
" 'ctrlp#tmpfm#get_tmpfilename_for()' has been called.
" FIXME: add call to this function from ctrlp#exit() (or a function called
" within that?).
fu! ctrlp#tmpfm#cleanup() abort
	if !exists('s:tmpfiles_dict') | retu 0 | en

	try
		let sucflag = !0
		let clientkeys_failed_dict = {}

		for clientkey in keys(s:tmpfiles_dict)
			try
				cal ctrlp#tmpfm#cleanup_for(clientkey)
			cat
				let sucflag = 0
				" MAYBE: just report errors here instead of storing the exception
				" information?
				let clientkeys_failed_dict[clientkey] = {
					\		'exception': v:exception,
					\		'throwpoint': v:throwpoint,
					\	}
			endt
		endfo

		if sucflag
			" FIXME: implement
			" remove the base directory, if necessary
			let tempfiles_base = simplify(get(s:, 'tempfiles_base'))
			" prev: if !empty(tempfiles_base)
			" prev: 	if s:tempfiles_base_isdir
			" prev: 		if isdirectory(tempfiles_base)
			" prev: 			if ctrlp#utils#remove_directory(tempfiles_base)
			" prev: 				" TODO: report error, too
			" prev: 			en
			" prev: 		en
			" prev: 	el
			" prev: 		" poor man's "file exists" check
			" prev: 		if glob(tempfiles_base) == tempfiles_base
			" prev: 			if delete(tempfiles_base)
			" prev: 				" TODO: report error, too
			" prev: 			en
			" prev: 		en
			" prev: 	en
			" prev: en
				" poor man's "file/dir exists" check
			if !empty(tempfiles_base) && glob(tempfiles_base) == tempfiles_base
				if s:tempfiles_base_isdir
					if ctrlp#utils#remove_directory(tempfiles_base)
						" TODO: report error, too
						let sucflag = 0
					en
				el
					" poor man's "file exists" check
					if delete(tempfiles_base)
						" TODO: report error, too
						let sucflag = 0
					en
				en
			en
		en

	fina
		let save_exc = v:exception
		try
			let except_pref = 'ctrlp#tmpfm#cleanup():'

			if empty(save_exc) && !sucflag
				th printf(
					\	'%s removing temporary files/dirs. client_keys=%s',
					\ except_pref, string(sort(keys(clientkeys_failed_dict))))
			en

		fina
			unl! s:tempfiles_base s:tmpfiles_dict
		endt
	endt

	retu !0
endf

" }}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
