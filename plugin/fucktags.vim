"********************************
"*** Copyright vbextreme 2017 ***
"*** License gplv3            ***
"******************************** 

if exists('g:fkt_plugin')
	finish
endif
let g:fkt_plugin = 1

if !exists('g:fkt_jobz')
	let g:fkt_jobz = expand('<sfile>:p:h') . '/fucktags.pl'
endif

if !exists('g:fkt_win_position')
	let g:fkt_win_position = "right"
endif

if !exists('g:fkt_win_size')
	let g:fkt_win_size = winwidth('%') / 3
endif

if !exists('g:fkt_win_id')
	let g:fkt_win_id = 0
endif

if !exists('g:fkt_char_open')
	let g:fkt_char_open = '-'
endif

if !exists('g:fkt_char_closed')
	let g:fkt_char_closed = '+'
endif

if !exists('g:fkt_dictags')
	let g:fkt_dictags = {}
endif

if !exists('g:fkt_dbg_remote')
	let g:fkt_dbg_remote = 0
endif

if !exists('g:fkt_dbg_local')
	let g:fkt_dbg_local = 0
endif

if !exists('g:fkt_save_path')
	let g:fkt_save_path = ''
endif

if !exists('g:fkt_save_current')
	let g:fkt_save_current = ''
endif

if !exists('g:fkt_save_current')
	let g:fkt_save_syntax = ''
endif

if !exists('g:fkt_offset_width')
	let g:fkt_offset_width = 6
endif

function! s:FkT_debug(title,descript)
	if !g:fkt_dbg_local
		return
	endif
perl << EOF
	my $pts = VIM::Eval('g:fkt_dbg_local');
	my $title = VIM::Eval('a:title');
	my $desc = VIM::Eval('a:descript');
	open my $fd, '>', "/dev/pts/$pts" or die 'fuckdebug';
	print $fd "[$title]$desc\n";
EOF
endfunction

function! s:FkT_win_open()
	if expand('%:t') != 'FkT_Buffer'
		call s:FkT_debug('winopen','save old file')
		let g:fkt_save_path = expand('%:p:h')
		let g:fkt_save_current = expand('%:p')
		let g:fkt_save_syntax = b:current_syntax
	endif
	if bufwinnr('FkT_Buffer') != -1
		return
	endif

	let l:mode = 0

	if g:fkt_win_position ==# "bottom"
		below new
		let l:mode = 1
	elseif g:fkt_win_position ==# "right"
		below vnew
	elseif g:fkt_win_position ==# "left"
		vnew
	else
		new
		let l:mode = 1
	endif

	setlocal buftype=nofile bufhidden=hide noswapfile nonumber
	file FkT_Buffer
	if l:mode 
		resize g:fkt_win_size
	else
		"exe 'resize' g:fkt_win_size
		call s:FkT_debug('vertical resize', g:fkt_win_size)
		exe 'vertical resize' g:fkt_win_size
	endif
	let g:fkt_win_id = winnr()
	nnoremap <buffer> e :call FkT_key_expand()<CR>
	nnoremap <buffer> E :call FkT_expand_all()<CR>
	nnoremap <buffer> q :call FkT_toggle_bar()<CR>
	nnoremap <buffer> j :call FkT_jump()<CR>
	"non muove il carret nella posizione voluta nnoremap <buffer> <LeftMouse> :call FkT_key_expand()<CR>
	setlocal filetype=fucktags_syntax
	hi clear CursorLine
	hi CursorLine cterm=underline
	setlocal cursorline
endfunction

function! s:FkT_win_close()
	if bufwinnr('FkT_Buffer') == -1
		return
	endif
	bd FkT_Buffer
endfunction

function! s:FkT_display_message(type,desc)
	if bufwinnr('FkT_Buffer') == -1
		call s:FkT_debug('display warning','window is closed')
		return
	endif
	call s:FkT_debug('display','begin')
	exe g:fkt_win_id . 'wincmd w'
	
	if g:fkt_win_position == 'left' || g:fkt_win_position == 'right'
		call s:FkT_debug('vertical resize', g:fkt_win_size)
		exe 'vertical resize' g:fkt_win_size
	endif

	1,$d	
	call append(0, a:type . ' '. a:desc)
endfunction

function! s:FkT_display_tags()
	if bufwinnr('FkT_Buffer') == -1
		call s:FkT_debug('display warning','window is closed')
		return
	endif
	call s:FkT_debug('display','begin')
	exe g:fkt_win_id . 'wincmd w'	
	
	if g:fkt_win_position == 'left' || g:fkt_win_position == 'right'
		call s:FkT_debug('vertical resize', g:fkt_win_size)
		exe 'vertical resize' g:fkt_win_size
	endif

	1,$d	
	let rcount = 0
	for fkey in keys(g:fkt_dictags)
		call s:FkT_debug('dictags',fkey)
		if g:fkt_dictags[fkey].EXPAND 
			call append(rcount, ' '. g:fkt_char_open . fkey)
		else
			call append(rcount, ' '. g:fkt_char_closed . fkey)
			continue
		endif

		let l:rcount = rcount + 1
		for tkey in keys(g:fkt_dictags[fkey])
			call s:FkT_debug('dictags.' . fkey, tkey)
			if tkey == 'EXPAND'
				continue
			endif
			call append(l:rcount, "\t". tkey)
			let l:rcount = l:rcount + 1
			for ele in g:fkt_dictags[fkey][tkey]
				call s:FkT_debug('dictags.' . fkey . '.' . tkey, ele.tag)
				call append(l:rcount, "\t\t". ele.tag)
				let l:rcount = l:rcount + 1
			endfor
		endfor
	endfor
endfunction

function! FkT_key_expand()
	let tkexpand = getline('.')
perl << EOF
	my $tk = VIM::Eval('tkexpand');
	my $cho = VIM::Eval('g:fkt_char_open');
	my $chc = VIM::Eval('g:fkt_char_closed');
	if ($tk =~ /[\'\"]+/) {
		VIM::DoCommand("let tkexpand = ''");
	}
	else {
		my ($ret) = $tk =~ /[ \t$chc$cho]*(.*)/;
		VIM::DoCommand("let tkexpand = '$ret'");
	}
EOF
	call s:FkT_debug('expand', tkexpand)
	
	if has_key(g:fkt_dictags, tkexpand)
		call s:FkT_debug('expand','invert')
		if g:fkt_dictags[tkexpand].EXPAND
			let g:fkt_dictags[tkexpand].EXPAND = 0
		else
			let g:fkt_dictags[tkexpand].EXPAND = 1
		endif
		call s:FkT_display_tags()
	endif
endfunction

function! FkT_expand_all()
	for fkey in keys(g:fkt_dictags)
		let g:fkt_dictags[fkey].EXPAND = 1
	endfor
	call s:FkT_display_tags()
endfunction

function! s:FkT_real_jump(bj,fj,rj) 
	"fare tutti i casi
	wincmd h
	if a:bj != ''
		call s:FkT_debug('real','buffer')
		exe 'buffer ' . a:bj
	elseif a:fj != ''
		call s:FkT_debug('real','edit')
		exe 'edit ' . a:fj
	endif
	call cursor(a:rj,1)
endfunction

function! FkT_jump()
	let tjump = getline('.')
perl << EOF
	my $tk = VIM::Eval('tjump');
	my $cho = VIM::Eval('g:fkt_char_open');
	my $chc = VIM::Eval('g:fkt_char_closed');

	if ( $tk =~ /[ \t$chc$cho]*([^\t]+)/ ) {
		$tk = $1;
		VIM::DoCommand("let tjump = '$tk'");
	}
	else{
		VIM::DoCommand("let tjump = ''");
	}
EOF
	call s:FkT_debug('select jump', tjump)
	
	for fkey in keys(g:fkt_dictags)
		if fkey == tjump
			call s:FkT_debug('jump to file','searching')
			if bufname(fkey) != '' 
				call s:FkT_debug('query','is open')
			else
				call s:FkT_debug('query', fkey . ' is not open ' . bufname(fkey) )
			endif
			call s:FkT_real_jump(bufname(fkey),fkey,1)
			return
		endif
		for tkey in keys(g:fkt_dictags[fkey])
			if tkey == 'EXPAND'
				continue
			elseif tkey == tjump
				call s:FkT_debug('warning', 'cant jump to type')
				return
			endif
			for ele in g:fkt_dictags[fkey][tkey]
				if ele.tag == tjump
					call s:FkT_debug('jump element', 'on line:' . ele.line)
					if bufname(fkey) != '' 
						call s:FkT_debug('query','is open')
					else
						call s:FkT_debug('query', fkey . ' is not open ' . bufname(fkey) )
					endif
					call s:FkT_real_jump(bufname(fkey),fkey,ele.line)
					return
				endif
			endfor
		endfor
	endfor
endfunction

function! s:FkT_callback_message(channel,msg)
	let l:json = json_decode(a:msg)
	
	if l:json[1].cmd == 'tags' 
		let g:fkt_dictags = deepcopy(l:json[1].dictags)
		if g:fkt_win_position == 'left' || g:fkt_win_position == 'right'
			let g:fkt_win_size = l:json[1].maxsize + g:fkt_offset_width
		endif
		
		call s:FkT_display_tags()
	elseif l:json[1].cmd == 'warning'
		call s:FkT_display_message(l:json[1].cmd, l:json[1].descript)
	elseif l:json[1].cmd == 'error'
		call s:FkT_display_message(l:json[1].cmd, l:json[1].descript)
	endif
endfunction

function! s:FkT_jobz(cmd)
	let l:job = job_start(g:fkt_jobz, { 
		\ 'in_mode':'json',
		\ 'out_mode':'json',
		\ 'in_io':'pipe',
		\ 'out_io':'pipe',
		\ 'callback': function('s:FkT_callback_message')
	\})
	let l:channel = job_getchannel(l:job)
	let l:path = expand('%:p:h')
	let l:cur = expand('%:p')
	let l:syn = b:current_syntax
	if expand('%:t') == 'FkT_Buffer'
		let l:path = g:fkt_save_path
		let l:cur = g:fkt_save_current
		let l:syn = g:fkt_save_syntax
	endif
	
	let l:test = { 'cmd' : a:cmd, 'path' : l:path, 'current' : l:cur, 'lang' : l:syn }
	if g:fkt_dbg_remote 
		let l:test.dbg = g:fkt_dbg_remote
	endif
	call ch_sendexpr(l:channel, l:test)
endfunction

function! FkT_generate_tags()
	call s:FkT_jobz('generate')
endfunction

function! FkT_parse_tags()
	call s:FkT_jobz('parse')
endfunction

function! FkT_toggle_bar()
	if bufwinnr('FkT_Buffer') == -1
		call s:FkT_win_open()
		call FkT_parse_tags()
	else
		call s:FkT_win_close()
	endif
endfunction
