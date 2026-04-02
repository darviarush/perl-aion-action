# NAME

Aion::Action::Http::Aurora - psgi-сервер с Coro

# SYNOPSIS

```perl
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

$response->is_success # -> 1
$response->status_line # => 200 OK
$response->decoded_content # => Answer: x=12

$response = $ua->get("http://127.0.0.1:$port?xyz");
$response->decoded_content # => Answer: xyz

$aurora->stop;

$response = $ua->get("http://127.0.0.1:$port");
$response->is_success # -> !!0
$response->status_line # => 500 Can't connect to 127.0.0.1:3071 (Connection refused)
$response->decoded_content # ^=> Can't connect
```

# DESCRIPTION

Aurora – легковесный PSGI-сервер для создания высоконагруженных сайтов.

# FEATURES

## name

Имя сервера. Оно используется, чтобы назвать порождённые короутины. Обязательно.

## host

Имя хоста на котором запущен сервер, используется в PSGI для формирования ссылок. По умолчанию – localhost.

## port

Порт сокета: если число – то **inet**, а если начинается с **unix:** – то имеется ввиду unix сокет (`unix:var/run/my.sock`). Обязателен.

## app

Колбэк для обработки запроса. Обязателен.

Принимает `$env` по стандарту PSGI, а возвращать может:

1. `[status, [headers], [body]]`.
2. `[status, [headers], filehandle]`.
3. `sub { my ($responder) = @_; ... }`

```perl
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

$response->status_line            # => 200 OK
$response->header('Content-Type') # => text/plain
$response->decoded_content        # => Lorem ipsum dolor sit amet

$aurora->stop;
```

## before

Подпрограмма для изменения формата данных запроса.

Получает параметр `$env` в формате PSGI, может его модифицировать или заменить (`$_[0] = $new_env`).

## after

Колбэк для изменения ответа.

Колбек получает параметры: 

* `$res` – ответ.
* `$env` – данные запроса. Если запрос битый (`400 Bad Request`), то будет `undef`.

## log

Логгер. По умолчанию `Log::Any` с категорией **http**.

## tcp_keepidle

Настройка сокета TCP_KEEPIDLE. Если клиент молчит столько секунд, ядро само пошлет ему пустой проверочный пакет.

## tcp_keepintvl

Настройка сокета TCP_KEEPINTVL. Если ответа нет после пустого проверочного пакета, ядро подождет столько секунд.

## tcp_keepcnt

Настройка сокета TCP_KEEPCNT. Ядро будет посылать пустой проверочный пакет столько раз через промежутки `tcp_keepintvl`. А затем, если ответа нет – закроет сокет.

## sd

Слушающий Coro-cокет.

## running_requests

Количество выполняющихся запросов.

## max_requests

Если количество запросов превысит этот лимит, то сервер будет прерывать каждое следующее соединение.

## recv_timeout

Таймаут на считывание заголовков запроса.

## send_timeout

Таймаут на отправку запроса.

## max_chunk_send

Максимальный размер пакета для отправки.

# SUBROUTINES

## open

Открывает и возвращает сокет.

## accept

Бесконечный цикл ожидания и выполнения запросов. Останавливавается, когда убирается sd. Например – с помощью метода `stop`. Ожидает остановки всех выполняющихся запросов.

## impulse ($ns, $paddr)

Парсит запрос и сендит ответ.

## http_recv ($ns, $paddr)

Получение из сокета запроса.

## http_send ($res, $ns, $env)

Отправляет ответ. `$res` – ответ в формате PSGI. `$ns` – клиентский сокет. Необязательный `$env` отправляется для обработчика `after`, когда распознан.

## stop

Закрывает сокет и останавливает бесконечный цикл `accept`.

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Action::Http::Aurora module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
