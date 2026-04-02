use common::sense; use open qw/:std :utf8/;  use Carp qw//; use Cwd qw//; use File::Basename qw//; use File::Find qw//; use File::Slurper qw//; use File::Spec qw//; use File::Path qw//; use Scalar::Util qw//;  use Test::More 0.98;  use String::Diff qw//; use Data::Dumper qw//; use Term::ANSIColor qw//;  BEGIN { 	$SIG{__DIE__} = sub { 		my ($msg) = @_; 		if(ref $msg) { 			$msg->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $msg; 			die $msg; 		} else { 			die Carp::longmess defined($msg)? $msg: "undef" 		} 	}; 	 	my $t = File::Slurper::read_text(__FILE__); 	 	my @dirs = File::Spec->splitdir(File::Basename::dirname(Cwd::abs_path(__FILE__))); 	my $project_dir = File::Spec->catfile(@dirs[0..$#dirs-4]); 	my $project_name = $dirs[$#dirs-4]; 	my @test_dirs = @dirs[$#dirs-4+2 .. $#dirs];  	$ENV{TMPDIR} = $ENV{LIVEMAN_TMPDIR} if exists $ENV{LIVEMAN_TMPDIR};  	my $dir_for_tests = File::Spec->catfile(File::Spec->tmpdir, ".liveman", $project_name, join("!", @test_dirs, File::Basename::basename(__FILE__))); 	 	File::Find::find(sub { chmod 0700, $_ if !/^\.{1,2}\z/ }, $dir_for_tests), File::Path::rmtree($dir_for_tests) if -e $dir_for_tests; 	File::Path::mkpath($dir_for_tests); 	 	chdir $dir_for_tests or die "chdir $dir_for_tests: $!"; 	 	push @INC, "$project_dir/lib", "lib"; 	 	$ENV{PROJECT_DIR} = $project_dir; 	$ENV{DIR_FOR_TESTS} = $dir_for_tests; 	 	while($t =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { 		my ($file, $code) = ($1, $2); 		$code =~ s/^#>> //mg; 		File::Path::mkpath(File::Basename::dirname($file)); 		File::Slurper::write_text($file, $code); 	} }  my $white = Term::ANSIColor::color('BRIGHT_WHITE'); my $red = Term::ANSIColor::color('BRIGHT_RED'); my $green = Term::ANSIColor::color('BRIGHT_GREEN'); my $reset = Term::ANSIColor::color('RESET'); my @diff = ( 	remove_open => "$white\[$red", 	remove_close => "$white]$reset", 	append_open => "$white\{$green", 	append_close => "$white}$reset", );  sub _string_diff { 	my ($got, $expected, $chunk) = @_; 	$got = substr($got, 0, length $expected) if $chunk == 1; 	$got = substr($got, -length $expected) if $chunk == -1; 	String::Diff::diff_merge($got, $expected, @diff) }  sub _struct_diff { 	my ($got, $expected) = @_; 	String::Diff::diff_merge( 		Data::Dumper->new([$got], ['diff'])->Indent(0)->Useqq(1)->Dump, 		Data::Dumper->new([$expected], ['diff'])->Indent(0)->Useqq(1)->Dump, 		@diff 	) }  # # NAME
# 
# Aion::Action::Http::Aurora - psgi-сервер с Coro
# 
# # SYNOPSIS
# 
subtest 'SYNOPSIS' => sub { 
use aliased 'Aion::Action::Http::Aurora' => 'Aurora';
use Coro;
use Coro::LWP;
use LWP::UserAgent;

use constant AURORA_PORT => 3071;

my $port = AURORA_PORT;

my $aurora = Aurora->new(
	name => 'aurora',
	port => $port,
	app => sub {
		my ($env) = @_;
		[200, [], ["Answer: ", $env->{QUERY_STRING}]]
	},
);

async { $aurora->accept };
cede;

my $ua = LWP::UserAgent->new;
my $response = $ua->get("http://127.0.0.1:$port?x=12");

local ($::_g0 = do {$response->is_success}, $::_e0 = do {1}); ::ok defined($::_g0) == defined($::_e0) && $::_g0 eq $::_e0, '$response->is_success # -> 1' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->status_line}, $::_e0 = "200 OK"); ::ok $::_g0 eq $::_e0, '$response->status_line # => 200 OK' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "Answer: x=12"); ::ok $::_g0 eq $::_e0, '$response->decoded_content # => Answer: x=12' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

$response = $ua->get("http://127.0.0.1:$port?xyz");
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "Answer: xyz"); ::ok $::_g0 eq $::_e0, '$response->decoded_content # => Answer: xyz' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

$aurora->stop;

$response = $ua->get("http://127.0.0.1:$port");
local ($::_g0 = do {$response->is_success}, $::_e0 = do {!!0}); ::ok defined($::_g0) == defined($::_e0) && $::_g0 eq $::_e0, '$response->is_success # -> !!0' or ::diag ::_struct_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->status_line}, $::_e0 = "500 Can't connect to 127.0.0.1:3071 (Connection refused)"); ::ok $::_g0 eq $::_e0, '$response->status_line # => 500 Can\'t connect to 127.0.0.1:3071 (Connection refused)' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "Can't connect"); ::ok $::_g0 =~ /^${\quotemeta $::_e0}/, '$response->decoded_content # ^=> Can\'t connect' or ::diag ::_string_diff($::_g0, $::_e0, 1); undef $::_g0; undef $::_e0;

# 
# # DESCRIPTION
# 
# Aurora – легковесный PSGI-сервер для создания высоконагруженных сайтов.
# 
# # FEATURES
# 
# ## name
# 
# Имя сервера. Оно используется, чтобы назвать порождённые короутины. Обязательно.
# 
# ## host
# 
# Имя хоста на котором запущен сервер, используется в PSGI для формирования ссылок. По умолчанию – localhost.
# 
# ## port
# 
# Порт сокета: если число – то **inet**, а если начинается с **unix:** – то имеется ввиду unix сокет (`unix:var/run/my.sock`). Обязателен.
# 
# ## app
# 
# Колбэк для обработки запроса. Обязателен.
# 
# Принимает `$env` по стандарту PSGI, а возвращать может:
# 
# 1. `[status, [headers], [body]]`.
# 2. `[status, [headers], filehandle]`.
# 3. `sub { my ($responder) = @_; ... }`
# 
::done_testing; }; subtest 'app' => sub { 
my $port = AURORA_PORT;

my $aurora = Aurora->new(
	name => 'aurora',
	port => $port,
	app => sub {
		my ($env) = @_;
		sub {
			my ($responder) = @_;
			my $writer = $responder->([200, ['Content-Type' => 'text/plain']]);

			$writer->write("Lorem ");
			$writer->write("ipsum ");			
			$writer->write("dolor sit amet");

			$writer->close;
		}
	},
);

async { $aurora->accept };
cede;

use FurlX::Coro;
my $ua = FurlX::Coro->new;
my $response = $ua->get("http://127.0.0.1:$port");

local ($::_g0 = do {$response->status_line}, $::_e0 = "200 OK"); ::ok $::_g0 eq $::_e0, '$response->status_line            # => 200 OK' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->header('Content-Type')}, $::_e0 = "text/plain"); ::ok $::_g0 eq $::_e0, '$response->header(\'Content-Type\') # => text/plain' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;
local ($::_g0 = do {$response->decoded_content}, $::_e0 = "Lorem ipsum dolor sit amet"); ::ok $::_g0 eq $::_e0, '$response->decoded_content        # => Lorem ipsum dolor sit amet' or ::diag ::_string_diff($::_g0, $::_e0); undef $::_g0; undef $::_e0;

$aurora->stop;

# 
# ## before
# 
# Подпрограмма для изменения формата данных запроса.
# 
# Получает параметр `$env` в формате PSGI, может его модифицировать или заменить (`$_[0] = $new_env`).
# 
# ## after
# 
# Колбэк для изменения ответа.
# 
# Колбек получает параметры: 
# 
# * `$res` – ответ.
# * `$env` – данные запроса. Если запрос битый (`400 Bad Request`), то будет `undef`.
# 
# ## log
# 
# Логгер. По умолчанию `Log::Any` с категорией **http**.
# 
# ## tcp_keepidle
# 
# Настройка сокета TCP_KEEPIDLE. Если клиент молчит столько секунд, ядро само пошлет ему пустой проверочный пакет.
# 
# ## tcp_keepintvl
# 
# Настройка сокета TCP_KEEPINTVL. Если ответа нет после пустого проверочного пакета, ядро подождет столько секунд.
# 
# ## tcp_keepcnt
# 
# Настройка сокета TCP_KEEPCNT. Ядро будет посылать пустой проверочный пакет столько раз через промежутки `tcp_keepintvl`. А затем, если ответа нет – закроет сокет.
# 
# ## sd
# 
# Слушающий Coro-cокет.
# 
# ## running_requests
# 
# Количество выполняющихся запросов.
# 
# ## max_requests
# 
# Если количество запросов превысит этот лимит, то сервер будет прерывать каждое следующее соединение.
# 
# ## recv_timeout
# 
# Таймаут на считывание заголовков запроса.
# 
# ## send_timeout
# 
# Таймаут на отправку запроса.
# 
# ## max_chunk_send
# 
# Максимальный размер пакета для отправки.
# 
# # SUBROUTINES
# 
# ## open
# 
# Открывает и возвращает сокет.
# 
# ## accept
# 
# Бесконечный цикл ожидания и выполнения запросов. Останавливавается, когда убирается sd. Например – с помощью метода `stop`. Ожидает остановки всех выполняющихся запросов.
# 
# ## impulse ($ns, $paddr)
# 
# Парсит запрос и сендит ответ.
# 
# ## http_recv ($ns, $paddr)
# 
# Получение из сокета запроса.
# 
# ## http_send ($res, $ns, $env)
# 
# Отправляет ответ. `$res` – ответ в формате PSGI. `$ns` – клиентский сокет. Необязательный `$env` отправляется для обработчика `after`, когда распознан.
# 
# ## stop
# 
# Закрывает сокет и останавливает бесконечный цикл `accept`.
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
# The Aion::Action::Http::Aurora module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.

	::done_testing;
};

::done_testing;
