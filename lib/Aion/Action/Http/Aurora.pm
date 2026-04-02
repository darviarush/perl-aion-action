package Aion::Action::Http::Aurora;
# PSGI-сервер

use common::sense;

use aliased 'Aion::Action::Http::Aurora::Writer' => 'Writer';
use Aion::Carp;
use Aion::Format::Url qw//;
use Coro::AnyEvent qw//;
use Coro qw/async/;
use Coro::Socket;
use Data::ULID qw/ulid/;
use Guard qw//;
use HTTP::Status qw//;
use List::Util qw//;
use Log::Any qw//;
use Socket::Linux qw//;
use Socket qw/IPPROTO_TCP AF_INET SOCK_STREAM SOL_SOCKET SO_REUSEADDR SO_KEEPALIVE 
	INADDR_ANY SOMAXCONN PF_UNIX SOMAXCONN sockaddr_in INADDR_ANY PF_UNIX PF_INET inet_aton/;

use config {
	TCP_KEEP_IDLE_SEC => 60,
	TCP_KEEP_INTERVAL_SEC => 3,
	TCP_KEEP_COUNT => 3,
	MAX_REQUESTS => 30_000,
	RECV_TIMEOUT => 3,
	SEND_TIMEOUT => 3,
	MAX_CHUNK_SEND => 8*1024,
};

use Aion;

BEGIN {
	subtype "HttpCode", as (Int & Range[100, 599]);
	subtype "PsgiPartialRes", as Tuple[&HttpCode, ArrayRef];
	subtype "PsgiRes", as Tuple[&HttpCode, ArrayRef, ArrayRef | FileHandle];
}

# Имя сервера. Оно используется, чтобы назвать порождённые короутины
has name => (is => 'ro+', isa => Str);

# Имя хоста на котором запущен сервер, используется в PSGI для формирования ссылок
has host => (is => 'ro', isa => Str, lazy => 0, default => sub { shift->name });

# Порт сокета: 
has port => (is => 'ro+', isa => PositiveInt|StrMatch[qr/^unix:/]);

# Подпрограмма для обработки запроса
has app => (is => 'ro+', isa => CodeRef);

# Подпрограмма для изменения формата данных запроса ($env)
has before => (is => 'ro', isa => Maybe[CodeRef]);

# Подпрограмма для изменения ответа
has after => (is => 'ro', isa => Maybe[CodeRef]);

# Логгер с категорией http
has log => (is => 'ro', isa => 'Log::Any::Proxy', default => Log::Any->get_logger(category => 'http'));

# Настройка сокета TCP_KEEPIDLE. Если клиент молчит столько секунд, ядро само пошлет ему пустой проверочный пакет
has tcp_keepidle => (is => 'ro', isa => PositiveInt, default => TCP_KEEP_IDLE_SEC);

# Настройка сокета TCP_KEEPINTVL. Если ответа нет, оно подождет столько секунд
has tcp_keepintvl => (is => 'ro', isa => PositiveInt, default => TCP_KEEP_INTERVAL_SEC);

# Настройка сокета TCP_KEEPCNT. И попробует еще столько раз
has tcp_keepcnt => (is => 'ro', isa => PositiveInt, default => TCP_KEEP_COUNT);

# Слушающий Coro-cокет
has sd => (is => 'ro-?!', isa => 'Coro::Socket', default => sub { shift->open });

# Короутина c accept
has listener_coro => (is => 'ro-?!', isa => 'Coro::State');

# Количество выполняющихся запросов
has running_requests => (is => 'ro-', isa => PositiveInt, default => 0);

# Если количество запросов превысит этот лимит, то сервер прервёт соединение
has max_requests => (is => 'ro', isa => PositiveInt, default => MAX_REQUESTS);

# Таймаут на считывание заголовков запроса
has recv_timeout => (is => 'ro', isa => PositiveInt, default => RECV_TIMEOUT);

# Таймаут на отправку запроса
has send_timeout => (is => 'ro', isa => PositiveInt, default => SEND_TIMEOUT);

# Максимальный размер пакета для отправки (Теорема Шеннона — Нейквиста)
has max_chunk_send => (is => 'ro', isa => PositiveInt, default => MAX_CHUNK_SEND);


my $genpkg = __PACKAGE__ . "::";
my $genseq = 0;
sub _gensym () {
	my $name = "S" . $genseq++;
	no strict 'refs';
	my $ref = \*{$genpkg . $name};
	delete $$genpkg{$name};
	$ref
}

# Открывает сокет
sub open {
	my ($self) = @_;
	my $sd = _gensym;
	my $port = $self->port;

	# если указан порт, то ожидается tcp-сокет
	if($port !~ s!^unix:!!) {
		socket $sd, AF_INET, SOCK_STREAM, getprotobyname("tcp") or die "socket: $!\n";
		# захватываем сокет, если он занят другим процессом
		setsockopt $sd, SOL_SOCKET, SO_REUSEADDR, pack("l", 1) or die "setsockopt reuseaddr: $!\n"; 
		# проверять что сокет существует и закрывать его если нет
		setsockopt $sd, SOL_SOCKET, SO_KEEPALIVE, pack("l", 1) or die "setsockopt KEEPALIVE: $!\n"; 
		# 1 minute keep-alive
		setsockopt($sd, IPPROTO_TCP, Socket::Linux::TCP_KEEPIDLE(), pack("i!", $self->tcp_keepidle)) or die "setsockopt KEEPIDLE: $!\n" if $Socket::{Linux::}{'TCP_KEEPIDLE'}{CODE};
		# 3 seconds for each attempt
		setsockopt($sd, IPPROTO_TCP, Socket::Linux::TCP_KEEPINTVL(), pack("i!", $self->tcp_keepintvl)) or die "setsockopt KEEPINTVL: $!\n" if $Socket::{Linux::}{'TCP_KEEPINTVL'}{CODE};
		# 3 times to try
		setsockopt($sd, IPPROTO_TCP, Socket::Linux::TCP_KEEPCNT(), pack("i!", $self->tcp_keepcnt)) or die "setsockopt KEEPCNT: $!\n" if $Socket::{Linux::}{'TCP_KEEPCNT'}{CODE};

		unless( bind $sd, sockaddr_in($port, INADDR_ANY) ) {
			if($! == 112) {
				Coro::AnyEvent::sleep 2;
				bind $sd, sockaddr_in($port, INADDR_ANY) or die "$$ bind: (".int($!).") $!\n";
			} else { die "$$ bind: (".int($!).") $!\n" }
		}
		listen $sd, SOMAXCONN or die "listen: $!\n";
	} else {
		socket $sd, PF_UNIX, SOCK_STREAM, 0 or die "socket: $!\n";
		unlink $port;
		bind $sd, Socket::sockaddr_un($port) or die "bind: $!\n";
		listen $sd, SOMAXCONN  or die "listen: $!\n";
	}
	
	Coro::Socket->new_from_fh($sd)
}

# Бесконечный цикл ожидания и выполнения запросов. Останавливавается, когда убирается sd
sub accept {
	my ($self) = @_;

	Aion::Carp->import;
	Coro::current->desc("$self->{name}-listener");
	$self->{listener_coro} = $Coro::current;
	
	my $shutdown_cv = AnyEvent->condvar;
	
	$self->stop->clear_sd if $self->has_sd;
	$self->sd;
	
	while( $self->{sd} ) {
		my ($ns, $paddr) = eval { $self->{sd}->accept };
		last unless $ns;

		# гарантированно закрывает сокет, когда происходит keep-alive по таймауту
		my $close_ns = Guard::guard {
			$self->{running_requests}--;
			if($ns) {
				$ns->shutdown(2);
				$ns->close;
			}
			
			$shutdown_cv->send if !$self->{sd} && $self->{running_requests} <= 0;
		};
		$self->{running_requests}++;
		
		# Не тратимся на ответ
		next if $self->{running_requests} >= $self->{max_requests};
	
		# Порождаем волокно
		async {
			Aion::Carp->import;
			Coro::current->desc("$self->{name}-request-${\fileno($ns)}");

			Coro::cede while $self->impulse($ns, $paddr);
			
			undef $close_ns;
		};
		Coro::cede;
	}
	
	# Ожидаем завершения всех выполняющихся короутин
	$shutdown_cv->recv if $self->{running_requests} > 0;
	
	$self
}

# Устанавливает таймер, который выбросит указанное исключение
sub _set_timer($$) {
	my ($timeout, $response) = @_;
	return if $timeout == 0;
	my $me = $Coro::current;
	AE::timer $timeout, $timeout, sub { $me->throw($response) }
}

# Парсит запрос и сендит ответ
sub impulse {
	my ($self, $ns, $paddr) = @_;
	
	Coro::current->{tid} = ulid();
	
	my $env;
	my $keep_alive = eval {
		# считывание запроса
		my $recv_timer = _set_timer $self->{recv_timeout}, [408, [], ["Recive Timeout ", $self->{recv_timeout}, "s"]];
		
		$env = $self->http_recv($ns, $paddr);
		
		undef $recv_timer;
		$self->http_send([400, [], ["Bad Request"]], $ns), return 0 unless $env;

		# исполнение запроса

		# веб-сокет сможет отключить таймер
		my $gateway_timer = _set_timer $self->{timeout}, [504, [], ["Gateway Timeout ", $self->{timeout}, "s"]];

		# Обработка ответа
		my $res = eval { $self->{app}->($env) } // $@;
		
		if(ref $res eq "CODE") {
			my $send_headers; my $closed;
			my $responder = sub {
				my ($res) = @_;
				PsgiPartialRes->validate($res, "PSGI headers");				
				push @$res, [];
				$self->http_send($res, $ns, $env);
				$send_headers = 1;

				bless {
					write => sub {
						my ($content) = @_;
					 	_utf8_encode($content);
						$ns->syswrite($content);
						Coro::cede;
						1
					},
					close => sub { $closed = 1 },
				}, Writer;
			};
			eval { $res->($responder) };
			$self->log->error($@) if $@;

			$self->log->warning("Responder do'nt closed") unless $closed;
			return 0 if $send_headers;
			$res = [500, [], ['Internal Server Error']];
		}
		
		unless($res ~~ PsgiRes) {
			$self->log->error(PsgiRes->detail($res, "PSGI result"));
			$res = [500, [], ['Internal Server Error']];
		}

		undef $gateway_timer;

		# отправка ответа
		my $send_timer = _set_timer $self->{send_timeout}, [522, [], ["Send Timeout ", $self->{send_timeout}, "s"]];

		$self->http_send($res, $ns, $env);
		
		undef $send_timer;
		
		0
	};
	# обрабытываем исключения таймеров
	if($@) {
		if($@ ~~ PsgiRes) { $self->http_send($@, $ns, $env) }
		else {
			$self->log->error($@);
			$self->http_send([500, [], ['Internal Server Error']], $ns, $env);
		}
	}
	
	return $keep_alive;
}

# Получение из сокета запроса
sub http_recv {
	my ($self, $ns, $paddr) = @_;

	no utf8; use bytes;
	
	my $true = 1==1;
	my $false = !$true;

	my $env = {
		SERVER_PORT => $self->{port},
		SERVER_NAME => $self->{host},
		SCRIPT_NAME => '',
		REMOTE_ADDR => $paddr,
		'psgi.version' => [ 1, 0 ],
		'psgi.errors'  => *STDERR,
		'psgi.input'   => $ns,
		'psgi.url_scheme' => 'http',
		'psgi.nonblocking'  => $true,
		'psgi.run_once'	    => $false,
		'psgi.multithread'  => $true,
		'psgi.multiprocess' => $false,						
		'psgi.streaming'	=> $true,
		'psgix.io'		    => $ns,
	};

	
	my $http = $ns->readline("\r\n");
	$self->log->infof("Bad Request `%s`", $http), return undef unless my ($method, $uri, $protocol) = $http =~ m!^(\w+) (\S+) (HTTP/\d+\.\d+)\r?$!;
	$self->log->info($http);
	
	$env->{REQUEST_METHOD}  = $method;
	$env->{REQUEST_URI}	    = $uri;
	$env->{SERVER_PROTOCOL} = $protocol;

	my($path, $query) = $uri =~ /\?/? ($`, $'): ($uri, '');

	$env->{PATH_INFO}	 = Aion::Format::Url::from_url_param($path);
	$env->{QUERY_STRING} = $query;

	# считываем заголовки
	my $token = qr/[^][\x00-\x1f\x7f()<>@,;:\\"\/?={} \t]+/;
	my $val_ref;
	my $header;
	while(defined($header = $ns->readline("\r\n")) and $header ne "\r\n") {
		if($header =~ s/^($token):[ \t]*//s) {
			my $k = uc $1;
			$k =~ y/-/_/;
			$k = "HTTP_$k" unless $k ~~ [qw/CONTENT_LENGTH CONTENT_TYPE/];
			
			$header =~ s//\r\n\z/;
			
			$val_ref = \$env->{$k};
			if (defined $$val_ref) {
				$$val_ref =~ s/\z/, $header/;
	        } else {
	            $$val_ref = $header;
	        }
		}
		elsif($header =~ s/^[ \t]+//) {
			$header =~ s//\r\n\z/;
			$$val_ref =~ s/\z/ $header/;
		}
		else {
			return undef;
		}
	}
	
	if($self->{before}) {
		eval { $self->{before}->($env) };
		$self->log->error($@) if $@;
	}
	
	$env
}

# Переводит в строку и декодирует
sub _utf8_encode(@) {
	no utf8; use bytes;
	for(@_) { $_ = "$_"; utf8::encode($_) if utf8::is_utf8($_) }
}

# Копирует файл из одного 
sub _copy_file {
	my ($self, $ns, $content) = @_;
	local $/ = \($self->{max_chunk_send});
	my $buf;
	$ns->syswrite($buf), Coro::cede while defined($buf = $content->getline);
}

# Ответ в формате PSGI
sub http_send {
	my ($self, $res, $ns, $env) = @_;
	
	if($self->{after}) {
		eval { $self->{after}->($res, $env) };
		$self->log->error($@) if $@;
	}
	
	PsgiRes->validate($res);
	
	my ($code, $headers, $content) = @$res;
	
	no utf8; use bytes;

	my @lines = List::Util::pairmap { _utf8_encode $a, $b; "$a: $b\r\n" } @$headers;
	
	my $version = "HTTP/1.0";
	my $reason = HTTP::Status::status_message($code);
	my $http = "$version $code $reason";
	$self->log->info($http);
	unshift @lines, "$http\r\n";
	push @lines, "\r\n";

	if (ref $content eq 'ARRAY') {
		_utf8_encode @$content;
		push @lines, @$content;

		my $limit = $self->{max_chunk_send};
		my @block;
		my $block_size = 0;

		while (@lines) {
			my $item = shift @lines;
			my $len = length $item;

			if ($block_size + $len <= $limit) {
				# Элемент входит целиком
				push @block, $item;
				$block_size += $len;
			}
			else {
				# Отрезаем кусок, чтобы добить блок до лимита
				my $need = $limit - $block_size;
				push @block, substr($item, 0, $need, "") if $need > 0;
				
				# Отправляем заполненный блок
				$ns->syswrite(join '', @block);
				Coro::cede;
				
				# Возвращаем остаток итема в очередь и сбрасываем блок
				unshift @lines, $item if length $item;
				@block = ();
				$block_size = 0;
			}
		}
		# Отправляем финальный остаток
		$ns->syswrite(join '', @block), Coro::cede if $block_size;
	}
	else {
		$ns->syswrite(join '', @lines);
		$self->_copy_file($ns, $content);
	}
	
	$self
}

# Закрывает главный сокет
sub stop {
	my ($self) = @_;
	my $sd = delete $self->{sd};
	
	if($sd) {
		$sd->shutdown(2) if tied *$sd;
		$sd->close;
	}
	
	my $listener = delete $self->{listener_coro};	
	$listener->throw("STOP") if $listener && !$listener->is_destroyed;
	
	$self
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Action::Http::Aurora - psgi-сервер с Coro

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Aurora – легковесный PSGI-сервер для создания высоконагруженных сайтов.

=head1 FEATURES

=head2 name

Имя сервера. Оно используется, чтобы назвать порождённые короутины. Обязательно.

=head2 host

Имя хоста на котором запущен сервер, используется в PSGI для формирования ссылок. По умолчанию – localhost.

=head2 port

Порт сокета: если число – то B<inet>, а если начинается с B<unix:> – то имеется ввиду unix сокет (C<unix:var/run/my.sock>). Обязателен.

=head2 app

Колбэк для обработки запроса. Обязателен.

Принимает C<$env> по стандарту PSGI, а возвращать может:

=over

=item 1. C<[status, [headers], [body]]>.

=item 2. C<[status, [headers], filehandle]>.

=item 3. C<sub { my ($responder) = @_; ... }>

=back

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

=head2 before

Подпрограмма для изменения формата данных запроса.

Получает параметр C<$env> в формате PSGI, может его модифицировать или заменить (C<$_[0] = $new_env>).

=head2 after

Колбэк для изменения ответа.

Колбек получает параметры: 

=over

=item * C<$res> – ответ.

=item * C<$env> – данные запроса. Если запрос битый (C<400 Bad Request>), то будет C<undef>.

=back

=head2 log

Логгер. По умолчанию C<Log::Any> с категорией B<http>.

=head2 tcp_keepidle

Настройка сокета TCP_KEEPIDLE. Если клиент молчит столько секунд, ядро само пошлет ему пустой проверочный пакет.

=head2 tcp_keepintvl

Настройка сокета TCP_KEEPINTVL. Если ответа нет после пустого проверочного пакета, ядро подождет столько секунд.

=head2 tcp_keepcnt

Настройка сокета TCP_KEEPCNT. Ядро будет посылать пустой проверочный пакет столько раз через промежутки C<tcp_keepintvl>. А затем, если ответа нет – закроет сокет.

=head2 sd

Слушающий Coro-cокет.

=head2 running_requests

Количество выполняющихся запросов.

=head2 max_requests

Если количество запросов превысит этот лимит, то сервер будет прерывать каждое следующее соединение.

=head2 recv_timeout

Таймаут на считывание заголовков запроса.

=head2 send_timeout

Таймаут на отправку запроса.

=head2 max_chunk_send

Максимальный размер пакета для отправки.

=head1 SUBROUTINES

=head2 open

Открывает и возвращает сокет.

=head2 accept

Бесконечный цикл ожидания и выполнения запросов. Останавливавается, когда убирается sd. Например – с помощью метода C<stop>. Ожидает остановки всех выполняющихся запросов.

=head2 impulse ($ns, $paddr)

Парсит запрос и сендит ответ.

=head2 http_recv ($ns, $paddr)

Получение из сокета запроса.

=head2 http_send ($res, $ns, $env)

Отправляет ответ. C<$res> – ответ в формате PSGI. C<$ns> – клиентский сокет. Необязательный C<$env> отправляется для обработчика C<after>, когда распознан.

=head2 stop

Закрывает сокет и останавливает бесконечный цикл C<accept>.

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Action::Http::Aurora module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
