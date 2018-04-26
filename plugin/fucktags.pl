#!/usr/bin/env perl
#********************************
#*** Copyright vbextreme 2017 ***
#*** License gplv3            ***
#******************************** 

use strict;
use warnings;
use JSON;
use File::Basename;

my $CTAGS = '/usr/bin/ctags';
$CTAGS = '/usr/local/bin/ctags' if -e '/usr/local/bin/ctags'; 
my $CTAGS_OPTIONS = '--format=2 --fields=+nK --excmd=pattern --recurse --totals -a';
my $DBG=0;
my $fdbg;

#############
### DEBUG ###
#############

sub dbg_init {
	return unless $DBG;
	my ($pts) = @_;
	open $fdbg, '>', "/dev/pts/$pts" or die 'fail debug';
}

sub dbg {
	return unless $DBG;
	my ($str) = @_;
	print $fdbg $str;
}

###########
### VIM ###
###########

sub vim_read {
	my $msg = <>;
	return decode_json($msg);
}

sub vim_reply_id {
	my ($id,$json) = @_;
	$json = "[$id,$json]";
	dbg "<reply>$json\n";
	print STDERR "$json\n";
}

sub vim_reply_error {
	my ($id,$err) = @_;
	my %msg = ('cmd' => 'error', 'descript' => $err );
	my $json = encode_json \%msg;
	vim_reply_id $id, $json;
}

sub vim_reply_warning {
	my ($id,$war) = @_;
	my %msg = ('cmd' => 'warning', 'descript' => $war );
	my $json = encode_json \%msg;
	vim_reply_id $id, $json;
}

sub vim_json_exists {
	my ($js,$prp) = @_;
	unless ( exists $js->[1]{$prp} ) {
		dbg "<generate>error not $prp\n";
		vim_reply_error $js->[0], "$prp not exists";
		exit 0;
	}
}

#############
### CTAGS ###
#############

sub call_ctags {
	my ($path,$file) = @_;
	return system("$CTAGS -f $path $CTAGS_OPTIONS $file &> /dev/null");
}

sub tags_remove_files {
	my ($path, $file) = @_;
	my $nwtags = $path . '.tmp';

	open my $fd, '>', $nwtags or return;
	open my $fs, '<', $path or return;
	while (my $line = <$fs>) {
		next if $line =~ /\Q$file\E/;
		print $fd $line;
	}
	unlink $path;
	rename $nwtags, $path;
}

sub search_file_reverse {
	my ($path,$match,$level) = @_;
	my @res;
	my @ret;

	for (my $i = 0; $i < $level; $i++) {
		@res = generate_search_file($path,$match);
		push @ret, @res if scalar @res; 
		$path = dirname($path);
	}
	return @ret;
}

sub search_file {
	my ($path,$match) = @_;
	my @res;
	push @res, $path;
	my @ret;
	while (my $p = pop @res) {
		#print "SEARCH::$p\n";
		opendir my $d, $p || die 'error path';
		while (my $file = readdir($d)) {
			next if $file =~ /^\./;
			$file = "$p/$file";
			if (-d $file ) {
				#print "ISDIR:$file\n";
				push @res, $file;
				next;
			}
			#print "FILE:$file\n";
			push @ret, $file if $file =~ /$match/;
		}
		closedir $d;
	}
	return @ret;
}

sub search_dir {
	my ($path,$match) = @_;
	my @res;
	push @res, $path;
	my @ret;
	while (my $p = pop @res) {
		#print "SEARCH::$p\n";
		opendir my $d, $p || die 'error path';
		while (my $file = readdir($d)) {
			next if $file =~ /^\./;
			$file = "$p/$file";
			if (-d $file ) {
				#print "ISDIR:$file\n";
				push @res, $file;
				push @ret, $file if $file =~ /$match/;
			}
		}
		closedir $d;
	}
	return @ret;
}

#############
### C/C++ ###
#############

sub generate_c_parse_include {
	my ($mkf) = @_;
	my $out = qx(make -p -f $mkf 2> /dev/null);
	my @inc = $out =~ /(-I[^ \t\n]+) /g;
	return '' if scalar @inc == 0;
	$out = '';
	for my $i (@inc) {
		$out .= $i . ' ';
	}
	return $out;
}

sub generate_c_try_include {
	my ($path) = @_;
	my ($mkf) = search_file_reverse($path,"Makefile|makefile",1);
	my $inc = '';
	($inc) = generate_c_parse_include($mkf) if $mkf;
	return ($inc)
}

sub generate_c_dependencies {
	my ($path,$cfile) = @_;
	my ($inc) = generate_c_try_include($path);
	my $out = qx(gcc $inc -M $cfile 2/dev/null);
	my @incs = split(/ /,$out);
	
	my @deps; 
	for my $i (@incs) {
		chomp $i;
		next if $i eq '\\';
		next if $i =~ /\.o/;
		push @deps, $i;
	}
	return @deps;
}

sub generate_c_tags {
	my ($path,$cfile) = @_;
	my @deps = generate_c_dependencies($path,$cfile);
	for my $file (@deps) {
		tags_remove_files("$path/tags",$file);
		call_ctags("$path/tags",$file);
	}
}

###############
### PERL5/6 ###
############### 

sub generate_perl6_path_uses {
	my ($module) = @_;
	my $out = qx(zef locate $module 2>/dev/null);
	for my $line (split(/\n/,$out)) {
		return $1 if $line =~ /^\Q$module\E => (.+)/;
	}
	return '';
}


sub generate_perl_path_uses {
	my ($module) = @_;
	my $out = qx(cpan -D $module 2>/dev/null);
	for my $line (split(/\n/,$out)) {
		return $1 if $line =~ /^[ \t]*(\/.+)/;
	}
	return '';
}

sub generate_perl_uses {
	my ($file, $lang) = @_;
	my @uses;
	open my $fd, '<', $file or return;
	for my $line (<$fd>) {
		if ( $line =~ /^[ \t]*use[ \t]+([^ \t;]+)/ ) {
			my $r = $1;
			if ($lang eq 'perl') {
				$r = generate_perl_path_uses($r);
			}
			else {
				$r = generate_perl6_path_uses($r);
			}
			push @uses, $r if $r ne '';
		}
	}
	return @uses;
}

sub generate_perl_tags {
	my ($path,$pfile,$lang) = @_;
	my @uses = generate_perl_uses($pfile,$lang);
	push @uses, $pfile;
	for my $file (@uses) {
		tags_remove_files("$path/tags",$file);
		call_ctags("$path/tags",$file);
	}
}

###############
### Generic ###
###############

sub generate_generic_tags {
	my ($path,$gfile) = @_;
	tags_remove_files("$path/tags",$gfile);
	call_ctags("$path/tags",$gfile);
}


#####################
### TAG GENERATOR ###
#####################

sub generate_select_lang {
	my ($lang,$path,$current) = @_;
	dbg "<lang>$lang\n";
	if ($lang =~ /^C|c/) {
		generate_c_tags($path, $current);
	}
	elsif ($lang =~ /^perl|Perl/) {
		generate_perl_tags($path, $current, $lang);
	}
	else {
		generate_generic_tags($path, $current);
	}
}

sub generate_tags {
	my ($json) = @_;
	dbg "<generate>" . $json->[1]->{'path'} . "\n" ;
	vim_json_exists($json,'path');
	vim_json_exists($json,'current');
	vim_json_exists($json,'lang');
	generate_select_lang($json->[1]->{'lang'}, $json->[1]->{'path'}, $json->[1]->{'current'});
	dbg "<generate>ok\n";
}

###################
### TAGS PARSES ###
###################

sub parse_tag_line {
	my ($line) = @_;
	#tag file regex type line typeref
	my (@tag) = $line =~ /([^\t]+)[\t]*([^\t]+)[\t]*\/(.+)\/\;\"[\t]*([^\t]+)[\t]*line:([0-9]+)[\t]*([^\t]*)[\t]*/;
	return @tag;
}

sub parse_getmax {
	my ($max,@elems) = @_;
	for my $ele (@elems) {
		$max = length $ele if length $ele > $max;
	}
	return $max;
}

sub parse_tag_to_json {
	my ($path,$current) = @_;
	my %msg = ('cmd' => 'tags');
	my $max_size = 0;
	dbg "<tags file>$path\n";
	unless (-f $path) {
		$msg{'cmd'} = 'warning';
		$msg{'descript'} = 'tags file not found';
		return encode_json \%msg;
	}
	open my $fd, '<', $path;
	while (my $line = <$fd>) {
		next if $line =~ /^!/;
		#tag file regex type line typeref
		my (@tag) = parse_tag_line($line);
		dbg "<parse file >$tag[1]\n";
		dbg "<parse tag  >$tag[0]\n";
		dbg "<parse regex>$tag[2]\n";
		dbg "<parse type >$tag[3]\n";
		dbg "<parse line >$tag[4]\n";
		dbg "<parse ref  >$tag[5]\n";
		$max_size = parse_getmax($max_size,@tag);
		my $expand = 0;
		$expand = 1 if $current =~ /\Q$tag[1]\E/;
		$msg{'dictags'}{$tag[1]}{'EXPAND'}=$expand; 
		push @{$msg{'dictags'}{$tag[1]}{$tag[3]}}, { 'regex' => $tag[2], 'tag' => $tag[0], 'line' => $tag[4], 'ref' => $tag[5] };
	}
	$msg{'maxsize'} = $max_size;
	return encode_json \%msg;
}

sub parse_tag {
	my ($json) = @_;
	dbg "<path>"  . $json->[1]->{'path'} . "\n";
	dbg "<current>"  . $json->[1]->{'current'} . "\n";
	vim_json_exists($json,'path');
	vim_json_exists($json,'current');

	my $reply = parse_tag_to_json($json->[1]->{'path'} . '/tags', $json->[1]->{'current'});
	vim_reply_id $json->[0], $reply;
}

############
### MAIN ###
############

my $json = vim_read;
$DBG = $json->[1]->{'dbg'} if exists $json->[1]->{'dbg'};
dbg_init($DBG);

dbg "<id>" . $json->[0] . "\n";
dbg "<command>" . $json->[1]->{'cmd'} . "\n";

if ($json->[1]->{'cmd'} eq 'generate') {
	generate_tags $json;
}

if ($json->[1]->{'cmd'} eq 'parse') {
	parse_tag $json;
}

if ($json->[1]->{'cmd'} eq 'generateandparse') {
	generate_tags $json;
	parse_tag $json;
}












