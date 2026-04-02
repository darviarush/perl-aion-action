use common::sense; use open qw/:std :utf8/;  use Carp qw//; use Cwd qw//; use File::Basename qw//; use File::Find qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  use String::Diff qw//; use Data::Dumper qw//; use Term::ANSIColor qw//;  BEGIN { 	$SIG{__DIE__} = sub { 		my ($msg) = @_; 		if(ref $msg) { 			$msg->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $msg; 			die $msg; 		} else { 			die Carp::longmess defined($msg)? $msg: "undef" 		} 	}; 	 	my $t = File::Slurper::read_text(__FILE__); 	 	my @dirs = File::Spec->splitdir(File::Basename::dirname(Cwd::abs_path(__FILE__))); 	my $project_dir = File::Spec->catfile(@dirs[0..$#dirs-4]); 	my $project_name = $dirs[$#dirs-4]; 	my @test_dirs = @dirs[$#dirs-4+2 .. $#dirs];  	$ENV{TMPDIR} = $ENV{LIVEMAN_TMPDIR} if exists $ENV{LIVEMAN_TMPDIR};  	my $dir_for_tests = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs, File::Basename::basename(__FILE__))); 	 	File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $dir_for_tests), File::Path::rmtree($dir_for_tests) if -e $dir_for_tests; 	File::Path::mkpath($dir_for_tests); 	 	chdir $dir_for_tests or die "chdir $dir_for_tests: $!"; 	 	push @INC, "$project_dir/lib", "lib"; 	 	$ENV{PROJECT_DIR} = $project_dir; 	$ENV{DIR_FOR_TESTS} = $dir_for_tests; 	 	while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { 		my ($file, $code) = ($1, $2); 		$code =~ s/^#>> //mg; 		File::Path::mkpath(File::Basename::dirname($file)); 		File::Slurper::write_text($file, $code); 	} }  my $white = Term::ANSIColor::color('BRIGHT_WHITE'); my $red = Term::ANSIColor::color('BRIGHT_RED'); my $green = Term::ANSIColor::color('BRIGHT_GREEN'); my $reset = Term::ANSIColor::color('RESET'); my @diff = ( 	remove_open => "$white\[$red", 	remove_close => "$white]$reset", 	append_open => "$white\{$green", 	append_close => "$white}$reset", );  sub _string_diff { 	my ($got, $expected, $chunk) = @_; 	$got = substr($got, 0, length $expected) if $chunk == 1; 	$got = substr($got, -length $expected) if $chunk == -1; 	String::Diff::diff_merge($got, $expected, @diff) }  sub _struct_diff { 	my ($got, $expected) = @_; 	String::Diff::diff_merge( 		Data::Dumper->new([$got], ['diff'])->Indent(0)->Useqq(1)->Dump, 		Data::Dumper->new([$expected], ['diff'])->Indent(0)->Useqq(1)->Dump, 		@diff 	) }  # # NAME
# 
# Aion::Action::Http::Proxy - балансир (HTTP-прокси) для разработки, перезапускающий воркеры при изменении кода
# 
# # SYNOPSIS
# 
# Файл etc/annotation/method.ann:
#@> etc/annotation/method.ann
#>> Tst::Action::Index#head,0=GET / „Index page”
#@< EOF
# 
# Файл lib/Tst/Action/Index.pm:
#@> lib/Tst/Action/Index.pm
#>> package Tst::Action::Index;
#>> use Aion;
#>> with qw/Aion::Action/;
#>> 
#>> #@method GET / „Index page”
#>> sub head { "Index" }
#>> 
#>> 1;
#@< EOF
# 
# Файл etc/annotation/run.ann:
#@> etc/annotation/run.ann
#>> Aion::Action::Http::Proxy#run,0=http:dev „Запуск HTTP-сервера разработки”
#>> Aion::Action::Http::Action#run,0=http:action „Запуск HTTP-сервера”
#@< EOF
# 
# Код:
subtest 'SYNOPSIS' => sub { 
use Coro;
use LWP::UserAgent;
use Coro::LWP;
use Aion::Fs qw/replace/;
use AnyEvent::Util qw/run_cmd/;

my $port = 3073;
my $dev_port = 3074;

async {
	my $cv = run_cmd([split /\s+/, "act dev -p $port -P $dev_port"]);
    $cv->recv and die "d'oh! something survived!"
};
cede;
Coro::AnyEvent::sleep 0.5;

my $ua = LWP::UserAgent->new;
my $response = $ua->get("http://127.0.0.1:$port");

local ($::_g0 = do {$response->status_line}, $::_e0 = "200 OK"); ::ok $::_g0 eq $::_e0, '$response->status_line # => 200 OK' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "Index"); ::ok $::_g0 eq $::_e0, '$response->decoded_content # => Index' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

$response = $ua->get("http://127.0.0.1:$port/x");
local ($::_g0 = do {$response->status_line}, $::_e0 = "404 Not Found"); ::ok $::_g0 eq $::_e0, '$response->status_line # => 404 Not Found' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

replace { s!GET /!GET /x!; s/"Index"/"Live"/ } 'lib/Tst/Action/Index.pm';
cede;

$response = $ua->get("http://127.0.0.1:$port");
local ($::_g0 = do {$response->status_line}, $::_e0 = "404 Not Found"); ::ok $::_g0 eq $::_e0, '$response->status_line # => 404 Not Found' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

$response = $ua->get("http://127.0.0.1:$port/x");
local ($::_g0 = do {$response->status_line}, $::_e0 = "200 OK"); ::ok $::_g0 eq $::_e0, '$response->status_line # => 200 OK' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "Live"); ::ok $::_g0 eq $::_e0, '$response->decoded_content # => Live' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

# 
# # DESCRIPTION
# 
# `Aion::Action::Http::Proxy` прозрачный прокси-сервер с автоматическим восстановлением отказов (Auto-Healing) и горячей перезагрузкой (Live Reload) серверов в дочерних процессах (`Aion::Action::Http::Action`). Обеспечивает высокую доступность, перенаправляя трафик на пул воркеров, и гарантирует идемпотентность состояний: при сбое процесса или изменении файловой системы (watch) инициирует бесшовный рестарт дочерних сервисов без потери соединений.
# 
# Он следит за изменением кодовой базы и перезапускает в этом случае сервера `action`. 
# 
# Запросы от браузера он пропускает через себя и задерживает их, если в этот момент все `action` перезагружаются.
# 
# # FEATURES
# 
# ## port
# 
# Порт на котором стартует сервер. Значение по умолчанию берётся из конфига `PORT`.
# 
# ## dev_port
# 
# Порт на котором стартует дочерний сервер для разработки (`action`). Значение по умолчанию берётся из конфига `Aion::Action::Http::Action->PORT`.
# 
# ## host
# 
# Хост на котором стартует сервер. Значение по умолчанию берётся из конфига `HOST`.
# 
# ## watch
# 
# Список каталогов для отслеживания.
# 
::done_testing; }; subtest 'watch' => sub { 
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

local ($::_g0 = do {$proxy->watch}, $::_e0 = do {['lib']}); ::is_deeply $::_g0, $::_e0, '$proxy->watch # --> [\'lib\']' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

# 
# ## watch_filter
# 
# Регулярка или подпрограмма для подходящих путей.
# 
::done_testing; }; subtest 'watch_filter' => sub { 
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

local ($::_g0 = do {$proxy->watch_filter}, $::_e0 = do {qr/\.(pm|yml)$/n}); ::ok defined($::_g0) == defined($::_e0) && $::_g0 eq $::_e0, '$proxy->watch_filter # -> qr/\.(pm|yml)$/n' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

# 
# ## annotation
# 
# Менеджер аннотаций.
# 
::done_testing; }; subtest 'annotation' => sub { 
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

local ($::_g0 = do {ref $proxy->annotation}, $::_e0 = "Aion::Annotation"); ::ok $::_g0 eq $::_e0, 'ref $proxy->annotation # => Aion::Annotation' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

# 
# ## corona
# 
# Сервер.
# 
::done_testing; }; subtest 'corona' => sub { 
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

local ($::_g0 = do {ref $proxy->corona}, $::_e0 = "Corona::Server"); ::ok $::_g0 eq $::_e0, 'ref $proxy->corona # => Corona::Server' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

# 
# # SUBROUTINES
# 
# ## run ()
# 
# @run http:dev „Запуск HTTP-сервера разработки”.
# 
# ## restart (@events)
# 
# Обработка изменения кодовой базы.
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
# The Aion::Action::Http::Proxy module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.

	::done_testing;
};

::done_testing;
