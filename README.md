# FuckTags v0.4
Create tags with dependencies resolver and display in window</br>

Released under GPL v3

## Revision
0.4 add focus on file expand
0.3 fix C/C++ dependencies, install procedure
0.2 add support to bash, fix warning on empty tags</br>
0.1 optimize ctags dependencies, add jump</br>
0.0 initial</br>

## How To
### Required 
VIM8 build with perl interpreter</br>
Perl</br>
Perl::JSON</br>
```
cpan -i JSON
```
or use your package manager
```
dnf search perl-json
```

### Install
#### Vundle
Place this in your .vimrc:
```
Plugin 'vbextreme/fucktags'
```
run the following in Vim:
```
:source %
:PluginInstall
```
For Vundle version < 0.10.2, replace Plugin with Bundle above.
#### VimPlug
Place this in your .vimrc:
```
Plug 'vbextreme/fucktags'
```
then run the following in Vim:
```
:source %
:PlugInstall
```
#### Pathogen
```
$ cd ~/.vim/bundle
$ git clone https://github.com/vbextreme/fucktags.git 
```

### Usage

Call function FkT_generate_tags() for generate tags file, automatic dependencies resolver for C/C++/Perl/Perl6 languages
```
:call FkT_generate_tags()
```
Call function FkT_toggle_bar() for open window with tags
```
:call FkT_toggle_bar()
```
you can remap
```
nmap <F8> :call FkT_toggle_bar()
nmap <F9> :call FkT_generate_tag()
inoremap <F8> :call FkT_toggle_bar()
inoremap <F9> :call FkT_generate_tag()
```
on window bar have mapped this key:
```
	q exit
	e expand
	E expand all
	j jump to code
```

### Configuration
Set this to change default window position:
```
let g:fkt_win_position = 'right'
```
Default: 'right'</br>
values: left, right, top, bottom</br>
</br>
Set this to change default char for open group:
```
let g:fkt_char_open = 'v'
```
Default: '-'</br>
</br>
Set this to change default char for closed group:
```
let g:fkt_char_closed = '>'
```
Default: '+'</br>
</br>

