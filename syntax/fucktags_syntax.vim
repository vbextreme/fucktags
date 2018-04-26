"********************************
"*** Copyright vbextreme 2017 ***
"*** License gplv3            ***
"******************************** 

if exists('b:current_syntax')
	finish
endif

let b:current_syntax = 'fucktags_syntax'

syn match fkt_file '^[ \t]*[+-]\+[^\t]\+'
syn match fkt_type '^\t[^\t]\+'
syn match fkt_tag '^\t\t[^\t]\+'

hi def link fkt_file Identifier 
hi def link fkt_type Label
hi def link fkt_tag Function


