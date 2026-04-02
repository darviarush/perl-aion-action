use common::sense; use open qw/:std :utf8/;  use Carp qw//; use Cwd qw//; use File::Basename qw//; use File::Find qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  use String::Diff qw//; use Data::Dumper qw//; use Term::ANSIColor qw//;  BEGIN { 	$SIG{__DIE__} = sub { 		my ($msg) = @_; 		if(ref $msg) { 			$msg->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $msg; 			die $msg; 		} else { 			die Carp::longmess defined($msg)? $msg: "undef" 		} 	}; 	 	my $t = File::Slurper::read_text(__FILE__); 	 	my @dirs = File::Spec->splitdir(File::Basename::dirname(Cwd::abs_path(__FILE__))); 	my $project_dir = File::Spec->catfile(@dirs[0..$#dirs-4]); 	my $project_name = $dirs[$#dirs-4]; 	my @test_dirs = @dirs[$#dirs-4+2 .. $#dirs];  	$ENV{TMPDIR} = $ENV{LIVEMAN_TMPDIR} if exists $ENV{LIVEMAN_TMPDIR};  	my $dir_for_tests = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs, File::Basename::basename(__FILE__))); 	 	File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $dir_for_tests), File::Path::rmtree($dir_for_tests) if -e $dir_for_tests; 	File::Path::mkpath($dir_for_tests); 	 	chdir $dir_for_tests or die "chdir $dir_for_tests: $!"; 	 	push @INC, "$project_dir/lib", "lib"; 	 	$ENV{PROJECT_DIR} = $project_dir; 	$ENV{DIR_FOR_TESTS} = $dir_for_tests; 	 	while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { 		my ($file, $code) = ($1, $2); 		$code =~ s/^#>> //mg; 		File::Path::mkpath(File::Basename::dirname($file)); 		File::Slurper::write_text($file, $code); 	} }  my $white = Term::ANSIColor::color('BRIGHT_WHITE'); my $red = Term::ANSIColor::color('BRIGHT_RED'); my $green = Term::ANSIColor::color('BRIGHT_GREEN'); my $reset = Term::ANSIColor::color('RESET'); my @diff = ( 	remove_open => "$white\[$red", 	remove_close => "$white]$reset", 	append_open => "$white\{$green", 	append_close => "$white}$reset", );  sub _string_diff { 	my ($got, $expected, $chunk) = @_; 	$got = substr($got, 0, length $expected) if $chunk == 1; 	$got = substr($got, -length $expected) if $chunk == -1; 	String::Diff::diff_merge($got, $expected, @diff) }  sub _struct_diff { 	my ($got, $expected) = @_; 	String::Diff::diff_merge( 		Data::Dumper->new([$got], ['diff'])->Indent(0)->Useqq(1)->Dump, 		Data::Dumper->new([$expected], ['diff'])->Indent(0)->Useqq(1)->Dump, 		@diff 	) }  # # NAME
# 
# Aion::Action::Http::Action - http-сервер с роутингом и событиями
# 
# # SYNOPSIS
# 
# Файл etc/annotation/method.ann:
#@> etc/annotation/method.ann
#>> Tst::Action::IndexAction#head,0=GET / „Index page”
#@< EOF
# 
# Файл lib/Tst/Action/IndexAction.pm:
#@> lib/Tst/Action/IndexAction.pm
#>> package Tst::Action::IndexAction;
#>> use Aion;
#>> 
#>> with qw/Aion::Action/;
#>> 
#>> #@method GET / „Index page”
#>> sub head {
#>> 	my ($self) = @_;
#>> 	"it's index"
#>> }
#>> 
#>> 1;
#@< EOF
# 
# Код:
subtest 'SYNOPSIS' => sub { 
use aliased 'Aion::Action::Http::Action' => 'Action';
use Coro;
use LWP::UserAgent;
use Coro::LWP;

my $port = 3073;
my $action = Action->new(port => $port);
async { $action->run };
cede;

my $response = LWP::UserAgent->new->get("http://127.0.0.1:$port");

local ($::_g0 = do {$response->is_success}, $::_e0 = do {1}); ::ok defined($::_g0) == defined($::_e0) && $::_g0 eq $::_e0, '$response->is_success # -> 1' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->status_line}, $::_e0 = "200 OK"); ::ok $::_g0 eq $::_e0, '$response->status_line # => 200 OK' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "it's index"); ::ok $::_g0 eq $::_e0, '$response->decoded_content # => it\'s index' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

$action->stop;

# 
# # DESCRIPTION
# 
# Сервер основан на http-сервере `Corona`. Он создаёт легковесный поток (`Coro`) на каждый запрос.
# 
# Список выполняющихся запросов содержится в актуальном состоянии в фиче `action`.
# 
# На запрос формируется объект (`Aion::Action::RequestEvent`), который проходит несколько событий сгруппированных по ловушкам исключений: 
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
# ## name
# 
# Имя сервера. По умолчанию `NAME` (aion-action).
# 
# ## host 
# 
# Хост сервера. По умолчанию `HOST` (localhost).
# 
# ## port
# 
# Порт на котором стартует сервер. По умолчанию `PORT` (3000).
# 
# ## action
# 
# Хеш выполняющихся запросов типа `Aion::Action::RequestEvent`.
# 
# ## routing
# 
# Роутинг.
# 
# ## emitter
# 
# Эмиттер.
# 
# ## corona
# 
# Сервер.
# 
# # SUBROUTINES
# 
# ## run ()
# 
# Команда `@run http:action` для запуска HTTP-сервера.
# 
# Мягко останавливается сигналом **INT**, **QUIT** или **TERM**.
# 
# Остановить без завершения выполняющихся запросов можно сигналом **KILL**.
# 
::done_testing; }; subtest 'run ()' => sub { 
use Aion::Fs qw/lay/;
lay "etc/annotation/method.ann", << 'END';
Tst::Action::SleepAction#sleepping,0=GET /sleep „Sleep”
END

# 
# Файл etc/annotation/run.ann:
#@> etc/annotation/run.ann
#>> Aion::Action::Http::Action#run,0=http:action „Запуск HTTP-сервера”
#@< EOF
# 
# Файл lib/Tst/Action/SleepAction.pm:
#@> lib/Tst/Action/SleepAction.pm
#>> package Tst::Action::SleepAction;
#>> use Aion;
#>> 
#>> with qw/Aion::Action/;
#>> 
#>> has sleep_sec => (is => 'ro', isa => Num, in => 'query');
#>> 
#>> #@method GET /sleep „Sleep”
#>> sub sleepping {
#>> 	my ($self) = @_;
#>> 	Coro::AnyEvent::sleep $self->sleep_sec;
#>> 	"sleepped"
#>> }
#>> 
#>> 1;
#@< EOF
# 
# Код:

use Log::Any::Adapter ('Stderr', log_level => 'debug');

use AnyEvent::Util qw/run_cmd/;

my $port = 3074;
my $action_pid;
my $done = AnyEvent->condvar;

async {
	my $cv = run_cmd([split /\s+/, "act action -p $port"], '$$' => \$action_pid);
    $cv->recv or die "d'oh! something survived!"
};

Coro::AnyEvent::sleep 0.5;

async {
	my $response = LWP::UserAgent->new->get("http://127.0.0.1:$port/sleep?sleep_sec=0.6");	
local ($::_g0 = do {$response->status_line}, $::_e0 = "200 OK"); ::ok $::_g0 eq $::_e0, '	$response->status_line # => 200 OK' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "sleepped"); ::ok $::_g0 eq $::_e0, '	$response->decoded_content # => sleepped' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
	$done->send;
};

Coro::AnyEvent::sleep 0.3;

local ($::_g0 = do {kill "TERM", $action_pid}, $::_e0 = "1"); ::ok $::_g0 eq $::_e0, 'kill "TERM", $action_pid # => 1' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

$done->recv;

# 
# ## request ($env)
# 
# Запрос к серверу.
# 
# ## form_error_response ($exception, $step)
# 
# Формирует ответ.
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
# The Aion::Action::Http::Action module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.

	::done_testing;
};

::done_testing;
