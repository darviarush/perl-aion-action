use common::sense; use open qw/:std :utf8/;  use Carp qw//; use Cwd qw//; use File::Basename qw//; use File::Find qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  use String::Diff qw//; use Data::Dumper qw//; use Term::ANSIColor qw//;  BEGIN { 	$SIG{__DIE__} = sub { 		my ($msg) = @_; 		if(ref $msg) { 			$msg->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $msg; 			die $msg; 		} else { 			die Carp::longmess defined($msg)? $msg: "undef" 		} 	}; 	 	my $t = File::Slurper::read_text(__FILE__); 	 	my @dirs = File::Spec->splitdir(File::Basename::dirname(Cwd::abs_path(__FILE__))); 	my $project_dir = File::Spec->catfile(@dirs[0..$#dirs-3]); 	my $project_name = $dirs[$#dirs-3]; 	my @test_dirs = @dirs[$#dirs-3+2 .. $#dirs];  	$ENV{TMPDIR} = $ENV{LIVEMAN_TMPDIR} if exists $ENV{LIVEMAN_TMPDIR};  	my $dir_for_tests = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs, File::Basename::basename(__FILE__))); 	 	File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $dir_for_tests), File::Path::rmtree($dir_for_tests) if -e $dir_for_tests; 	File::Path::mkpath($dir_for_tests); 	 	chdir $dir_for_tests or die "chdir $dir_for_tests: $!"; 	 	push @INC, "$project_dir/lib", "lib"; 	 	$ENV{PROJECT_DIR} = $project_dir; 	$ENV{DIR_FOR_TESTS} = $dir_for_tests; 	 	while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { 		my ($file, $code) = ($1, $2); 		$code =~ s/^#>> //mg; 		File::Path::mkpath(File::Basename::dirname($file)); 		File::Slurper::write_text($file, $code); 	} }  my $white = Term::ANSIColor::color('BRIGHT_WHITE'); my $red = Term::ANSIColor::color('BRIGHT_RED'); my $green = Term::ANSIColor::color('BRIGHT_GREEN'); my $reset = Term::ANSIColor::color('RESET'); my @diff = ( 	remove_open => "$white\[$red", 	remove_close => "$white]$reset", 	append_open => "$white\{$green", 	append_close => "$white}$reset", );  sub _string_diff { 	my ($got, $expected, $chunk) = @_; 	$got = substr($got, 0, length $expected) if $chunk == 1; 	$got = substr($got, -length $expected) if $chunk == -1; 	String::Diff::diff_merge($got, $expected, @diff) }  sub _struct_diff { 	my ($got, $expected) = @_; 	String::Diff::diff_merge( 		Data::Dumper->new([$got], ['diff'])->Indent(0)->Useqq(1)->Dump, 		Data::Dumper->new([$expected], ['diff'])->Indent(0)->Useqq(1)->Dump, 		@diff 	) }  # 
# # NAME
# 
# Aion::Action::Routing - http-роутер
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
use Aion::Action::Routing;

my $routing = Aion::Action::Routing->new;
my ($method, $slug) = $routing->trace('GET', '/hello/World');

my %method = (
	pkg => 'MyApp',
	sub => 'index',
	remark => '„Say hello”',
);

local ($::_g0 = do {$method}, $::_e0 = do {\%method}); ::is_deeply $::_g0, $::_e0, '$method # --> \%method' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$slug}, $::_e0 = do {{name => 'World'}}); ::is_deeply $::_g0, $::_e0, '$slug   # --> {name => \'World\'}' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

my ($not_found, $slug_found) = $routing->trace('POST', '/hello/World');
local ($::_g0 = do {$not_found}, $::_e0 = do {undef}); ::ok defined($::_g0) == defined($::_e0) && $::_g0 eq $::_e0, '$not_found  # -> undef' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$slug_found}, $::_e0 = do {{name => 'World'}}); ::is_deeply $::_g0, $::_e0, '$slug_found # --> {name => \'World\'}' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

# 
# # DESCRIPTION
# 
# Роутер для получения по URL-пути роута. Так же позволяет получить из пути ЧПУ (человекопонятные урлы).
# 
# # CONFIGURABLE CONSTANTS
# 
# # INI
# 
# Путь к собранным из аннотаций методам.
# 
# # FEATURES
# 
# ## ini
# 
# Путь к собранным из аннотаций методам. По умолчанию – `INI`.
# 
# ## methods
# 
# Список методов.
# 
# # SUBROUTINES
# 
# ## trace ($method, $path)
# 
# Находит соответствующий роут.
# 
# Возвращает список из двух пунктов: хеша с описанием метода и хеша с ЧПУ распознанных в пути.
# 
# Если первый пункт `undef`, а второй не `undef`, а хеш, то это значит, что роут найден, но метода (`$method`) в нём нет.
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
# The Aion::Action::Routing module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.

	::done_testing;
};

::done_testing;
