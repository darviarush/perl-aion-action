use common::sense; use open qw/:std :utf8/;  use Carp qw//; use Cwd qw//; use File::Basename qw//; use File::Find qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  use String::Diff qw//; use Data::Dumper qw//; use Term::ANSIColor qw//;  BEGIN { 	$SIG{__DIE__} = sub { 		my ($msg) = @_; 		if(ref $msg) { 			$msg->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $msg; 			die $msg; 		} else { 			die Carp::longmess defined($msg)? $msg: "undef" 		} 	}; 	 	my $t = File::Slurper::read_text(__FILE__); 	 	my @dirs = File::Spec->splitdir(File::Basename::dirname(Cwd::abs_path(__FILE__))); 	my $project_dir = File::Spec->catfile(@dirs[0..$#dirs-3]); 	my $project_name = $dirs[$#dirs-3]; 	my @test_dirs = @dirs[$#dirs-3+2 .. $#dirs];  	$ENV{TMPDIR} = $ENV{LIVEMAN_TMPDIR} if exists $ENV{LIVEMAN_TMPDIR};  	my $dir_for_tests = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs, File::Basename::basename(__FILE__))); 	 	File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $dir_for_tests), File::Path::rmtree($dir_for_tests) if -e $dir_for_tests; 	File::Path::mkpath($dir_for_tests); 	 	chdir $dir_for_tests or die "chdir $dir_for_tests: $!"; 	 	push @INC, "$project_dir/lib", "lib"; 	 	$ENV{PROJECT_DIR} = $project_dir; 	$ENV{DIR_FOR_TESTS} = $dir_for_tests; 	 	while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { 		my ($file, $code) = ($1, $2); 		$code =~ s/^#>> //mg; 		File::Path::mkpath(File::Basename::dirname($file)); 		File::Slurper::write_text($file, $code); 	} }  my $white = Term::ANSIColor::color('BRIGHT_WHITE'); my $red = Term::ANSIColor::color('BRIGHT_RED'); my $green = Term::ANSIColor::color('BRIGHT_GREEN'); my $reset = Term::ANSIColor::color('RESET'); my @diff = ( 	remove_open => "$white\[$red", 	remove_close => "$white]$reset", 	append_open => "$white\{$green", 	append_close => "$white}$reset", );  sub _string_diff { 	my ($got, $expected, $chunk) = @_; 	$got = substr($got, 0, length $expected) if $chunk == 1; 	$got = substr($got, -length $expected) if $chunk == -1; 	String::Diff::diff_merge($got, $expected, @diff) }  sub _struct_diff { 	my ($got, $expected) = @_; 	String::Diff::diff_merge( 		Data::Dumper->new([$got], ['diff'])->Indent(0)->Useqq(1)->Dump, 		Data::Dumper->new([$expected], ['diff'])->Indent(0)->Useqq(1)->Dump, 		@diff 	) }  # # NAME
# 
# Aion::Action::Link - генератор ссылок по роуту
# 
# # SYNOPSIS
# 
# Файл etc/annotation/method.ann:
#@> etc/annotation/method.ann
#>> MyApp#index,0=GET	/hello/{name}	„Say hello”
#>> MyApp#show,0=POST	/user/{id}		„Show user”
#@< EOF
# 
# Код:
subtest 'SYNOPSIS' => sub { 
use Aion::Action::Link;

my $link = Aion::Action::Link->new;

local ($::_g0 = do {$link->generate('MyApp#index', {name => 'World'})}, $::_e0 = "/hello/World"); ::ok $::_g0 eq $::_e0, '$link->generate(\'MyApp#index\', {name => \'World\'}) # => /hello/World' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$link->generate('POST MyApp#show', {id => 123})}, $::_e0 = "/user/123"); ::ok $::_g0 eq $::_e0, '$link->generate(\'POST MyApp#show\', {id => 123})   # => /user/123' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

eval {$link->generate('MyApp', {})}; local ($::_g0 = $@, $::_e0 = 'Action `MyApp` corrupt!'); ok defined($::_g0) && $::_g0 =~ /^${\quotemeta $::_e0}/, '$link->generate(\'MyApp\', {})                           # @-> Action `MyApp` corrupt!' or ::diag ::_string_diff($::_g0, $::_e0, 1); undef $::_g0; undef $::_e0;
eval {$link->generate('MyApp#show', {})}; local ($::_g0 = $@, $::_e0 = 'id not slug in /user/{id}!'); ok defined($::_g0) && $::_g0 =~ /^${\quotemeta $::_e0}/, '$link->generate(\'MyApp#show\', {})                      # @-> id not slug in /user/{id}!' or ::diag ::_string_diff($::_g0, $::_e0, 1); undef $::_g0; undef $::_e0;
eval {$link->generate('POST MyApp#index', {name => 'World'})}; local ($::_g0 = $@, $::_e0 = 'POST MyApp#index not found!'); ok defined($::_g0) && $::_g0 =~ /^${\quotemeta $::_e0}/, '$link->generate(\'POST MyApp#index\', {name => \'World\'}) # @-> POST MyApp#index not found!' or ::diag ::_string_diff($::_g0, $::_e0, 1); undef $::_g0; undef $::_e0;

# 
# # DESCRIPTION
# 
# Генерирует ссылку по роуту находя её по классу и методу к которым привязан обработчик с помощью аннотации `@method`.
# 
# # FEATURES
# 
# ## routing
# 
# Роутинг.
# 
# # SUBROUTINES
# 
# ## generate ($action, $slug)
# 
# Генерирует ссылку по параметрам:
# 
# * `$action` – строка формата `$pkg#$method` или `$via $pkg#$method`. В первом случае `$via` принимаеться за `GET`.
# * `$slug` – хеш с ЧПУ для вставки в параметры пути.
# 
# Если к одному методу инстанса привязано несколько обработчиков, то будет выбран первый согласно сортировке роутов по возрастанию.
# 
# # AUTHOR
# 
# Yaroslav O. Kosmina <dart@cpan.org>
# 
# # LICENSE
# 
# ⚖ **GPLv3**
# 
# # COPYRIGHT
# 
# The Aion::Action::Link module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.

	::done_testing;
};

::done_testing;
