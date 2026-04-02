use common::sense; use open qw/:std :utf8/;  use Carp qw//; use Cwd qw//; use File::Basename qw//; use File::Find qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  use String::Diff qw//; use Data::Dumper qw//; use Term::ANSIColor qw//;  BEGIN { 	$SIG{__DIE__} = sub { 		my ($msg) = @_; 		if(ref $msg) { 			$msg->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $msg; 			die $msg; 		} else { 			die Carp::longmess defined($msg)? $msg: "undef" 		} 	}; 	 	my $t = File::Slurper::read_text(__FILE__); 	 	my @dirs = File::Spec->splitdir(File::Basename::dirname(Cwd::abs_path(__FILE__))); 	my $project_dir = File::Spec->catfile(@dirs[0..$#dirs-3]); 	my $project_name = $dirs[$#dirs-3]; 	my @test_dirs = @dirs[$#dirs-3+2 .. $#dirs];  	$ENV{TMPDIR} = $ENV{LIVEMAN_TMPDIR} if exists $ENV{LIVEMAN_TMPDIR};  	my $dir_for_tests = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs, File::Basename::basename(__FILE__))); 	 	File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $dir_for_tests), File::Path::rmtree($dir_for_tests) if -e $dir_for_tests; 	File::Path::mkpath($dir_for_tests); 	 	chdir $dir_for_tests or die "chdir $dir_for_tests: $!"; 	 	push @INC, "$project_dir/lib", "lib"; 	 	$ENV{PROJECT_DIR} = $project_dir; 	$ENV{DIR_FOR_TESTS} = $dir_for_tests; 	 	while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { 		my ($file, $code) = ($1, $2); 		$code =~ s/^#>> //mg; 		File::Path::mkpath(File::Basename::dirname($file)); 		File::Slurper::write_text($file, $code); 	} }  my $white = Term::ANSIColor::color('BRIGHT_WHITE'); my $red = Term::ANSIColor::color('BRIGHT_RED'); my $green = Term::ANSIColor::color('BRIGHT_GREEN'); my $reset = Term::ANSIColor::color('RESET'); my @diff = ( 	remove_open => "$white\[$red", 	remove_close => "$white]$reset", 	append_open => "$white\{$green", 	append_close => "$white}$reset", );  sub _string_diff { 	my ($got, $expected, $chunk) = @_; 	$got = substr($got, 0, length $expected) if $chunk == 1; 	$got = substr($got, -length $expected) if $chunk == -1; 	String::Diff::diff_merge($got, $expected, @diff) }  sub _struct_diff { 	my ($got, $expected) = @_; 	String::Diff::diff_merge( 		Data::Dumper->new([$got], ['diff'])->Indent(0)->Useqq(1)->Dump, 		Data::Dumper->new([$expected], ['diff'])->Indent(0)->Useqq(1)->Dump, 		@diff 	) }  # # NAME
# 
# Aion::Action::RequestEvent - событие для http-сервера
# 
# # SYNOPSIS
# 
subtest 'SYNOPSIS' => sub { 
use Aion::Action::RequestEvent;

my $event = Aion::Action::RequestEvent->new;

local ($::_g0 = do {ref $event}, $::_e0 = "Aion::Action::RequestEvent"); ::ok $::_g0 eq $::_e0, 'ref $event # => Aion::Action::RequestEvent' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

# 
# # DESCRIPTION
# 
# Данное событие содержит всю информацию необходимую для обработки http-запроса и формирования ответа. А именно: запрос, ответ, сервер и исключения появившиеся на этапах выполнения и обработки ответа.
# 
# Объект данного класса проходит несколько событий сгруппированных по ловушкам исключений: 
# 
# * `drop` – запрос «капнул».
# * `MyClass.my_sub.drop` – если роут распознан, то срабатывает экшн с его классом, методом и словом `drop` через точку.
# * `MyClass.my_sub.leave` – после экшена.
# 
# Если тут происходит исключение, то оно записывается в свойство `exception`.
# 
# * `200` – сформирован ответ с данным кодом.
# * `2xx` – ответ с кодами в данном диапазоне.
# * `code` – ответ.
# 
# Если тут происходит исключение, то оно записывается в свойство `exception_code`.
# 
# * `leave` – ответ покидает сервер и отправляется пользователю.
# 
# Если тут происходит исключение, то возвращается сырой ответ `500`.
# 
# # FEATURES
# 
# ## server
# 
# http-сервер типа `Aion::Action::Http::Action`.
# 
# ## request
# 
# Запрос типа `Plack::Request`.
# 
# ## response
# 
# Ответ типа `Plack::Response`. До формирования ответа заполняется сервером временным ответом с кодом `102 Procession`.
# 
# ## exception
# 
# Исключение, которое могло произойти во время выполнения.
# А именно: события drop и привязанного к роуту экшена.
# Может быть любого типа.
# 
# ## exception_code
# 
# Исключение, которое могло произойти во время событий nnn, nxx и code.
# Может быть любого типа.
# 
# # SUBROUTINES
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
# The Aion::Action::RequestEvent module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.

	::done_testing;
};

::done_testing;
