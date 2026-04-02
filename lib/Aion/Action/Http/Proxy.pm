package Aion::Action::Http::Proxy;
# Сервер http

use common::sense;

use Aion::Action::Http::Action;
use Aion::Action::Http::Aurora;
use Aion::Action::Http::Proxy::Instance;
use Aion::Annotation;
use Aion::Carp;
use Aion::Format qw/warncolor trapperr/;
use Coro qw/async async_pool/;
use Coro::AnyEvent;
use FurlX::Coro;
use IO::Socket::SSL qw//;
use Plack::Request qw//;
use URI;

use config {
	HOST => "*",
	PORT => 3001,
	TIMEOUT => 1,
	READY_TIMEOUT => 0.5,
	WATCH => ['lib'],
	WATCH_FILTER => qr/\.(pm|yml)$/n,
};

use constant HEADERS_CONTENT_PLAIN => ['Content-Type' => 'text/plain; charset=utf-8'];

use Aion;

with 'Aion::Run';

# Хост на котором стартует сервер
has host => (is => 'ro', isa => Str, arg => '-h', default => HOST);

# Порт на котором стартует сервер
has port => (is => 'ro', isa => PositiveInt, arg => '-p', default => PORT);

# Порты на которых стартуют дочерние сервера для разработки
has dev_ports => (is => 'ro', isa => ArrayRef[PositiveInt], arg => '-P', lazy => 0, default => sub { +[Aion::Action::Http::Action->PORT] });

# № процессов с серверами action
has instances => (is => 'ro-', isa => ArrayRef['Aion::Action::Http::Proxy::Instance'], default => sub {
	my ($self) = @_;
	+[map Aion::Action::Http::Proxy::Instance->new(port => $_, proxy => $self), @{$self->dev_ports}]
});

# Список каталогов для отслеживания
has watch => (is => 'ro', isa => ArrayRef[Str], arg => '-w', default => WATCH);

# Регулярка или подпрограмма для подходящих путей
has watch_filter => (is => 'ro', isa => Str|RegexpRef|CodeRef, arg => '-W', default => WATCH_FILTER);

# Менеджер аннотаций
has annotation => (is => 'ro', isa => 'Aion::Annotation', eon => 1);

# Сервер
has aurora => (is => 'ro', isa => 'Aion::Action::Http::Aurora', default => sub {
	my ($self) = @_;
	Aion::Action::Http::Aurora->new(
		name  => $self->name,
		host  => $self->host,
		port  => $self->port,
		app   => sub { $self->request(@_) },
	)
});

# Таймаут запроса к инстансу
has timeout => (is => 'ro', isa => PositiveInt, default => TIMEOUT);

# Асинхронный UserAgent с настройками для Unix-сокета
has user_agent => (is => 'ro', isa => 'FurlX::Coro', default => sub {
	my ($self) = @_;
	FurlX::Coro->new(
		max_redirects => 0,
		timeout => $self->timeout,
		ssl_config	=> { 
			SSL_verify_mode => 0,
		},
	)
});

# Останавливает запросы, пока не появятся готовые инстансы
has ready => (is => 'ro', isa => 'Coro::Signal', lazy => 0, default => sub { Coro::Signal->new });

# Установлен таймаут на сброс ожидания пока хоть один из инстансов станет ready
has is_ready_timeout => (is => 'rw', isa => Bool);

# Таймаут на сброс ожидания ready
has ready_timeout => (is => 'ro', isa => Num, default => READY_TIMEOUT);

# Количество выполняющихся запросов
has count_requests => (is => 'rw', isa => PositiveInt, default => 0);

#@run http:dev „Запуск HTTP-сервера разработки”
sub run {
	my ($self) = @_;
	local $|=1;
	$SIG{__DIE__} = $SIG{__WARN__} = \&Aion::Carp::handler;

	async {			
		# Запускаем первый раз
		$self->restart;
		
		# Слушаем изменения в кодовой базе
		trapperr { require 'AnyEvent::Filesys::Notify' };
		my $notifier = AnyEvent::Filesys::Notify->new(
			dirs	 => $self->watch,
			filter   => $self->watch_filter,
			interval => 1.0,
			cb	   => sub { $self->restart(@_) },
		);

		Coro::AnyEvent::idle;
	};
	Coro::cede;

	warncolor "Proxy #{bright_blue}%s#r started on port #red%s#r\n", ref $self, $self->port;
	$self->aurora->run;
}

# Обработчик запроса
sub request {
	no utf8;
	use bytes;

	my ($self, $env) = @_;
	my $req = Plack::Request->new($env);
	my $input = $env->{'psgi.input'};
	my $content_length = $env->{CONTENT_LENGTH} || 0;
	my $bytes_read = 0;

	for(;;) {
		my $instance = $self->select_instance;
	
		if(!defined $instance) {
			# Возвращаем 502 Bad Gateway
			return [502, HEADERS_CONTENT_PLAIN, ["502 Bad Gateway"]];
		}

		# Формируем URL с Unix-сокетом
		my $uri = URI->new("http://127.0.0.1:$instance->{port}");
		$uri->path($req->path);
		$uri->query($req->query_string);

		# Добавляем проксирование:
		$req->headers->header('X-Forwarded-For' => $req->address); 
		$req->headers->header('X-Forwarded-Host' => $req->host);
		
		# Создаем HTTP-запрос
		my $http_req = HTTP::Request->new(
			$req->method => $uri,
			$req->headers,
			sub {
				my $to_read = $content_length - $bytes_read;
				return undef if $to_read <= 0;
		
				my $buf;
				my $chunk_size = $to_read > 65536? 65536: $to_read;
				
				my $len = $input->read($buf, $chunk_size);
				
				$bytes_read += $len, return $buf if $len > 0;
				return undef;
			}
		);
	
		# Увеличиваем счётчик активных запросов
		$self->{count_requests}++;
		$instance->{count_requests}++;
	
		# Выполняем асинхронный запрос
		my $res = $self->user_agent->request($http_req);
		
		$instance->{count_requests}--;
		$self->{count_requests}--;
	
		if($res->is_success) {
			return +[
				$res->code,
				[map { ($_ => $res->header($_)) } $res->header_field_names],
				[$res->content]
			]
		}
	
		# Воркер не ответил – помечаем его как неготовый и рестартуем
		$instance->is_ready(0);
		async { $instance->restart };
		Coro::cede;
	}
}

# Обработка изменения кодовой базы
sub restart {
	my ($self, @events) = @_;
	warncolor "#{magenta}restart#r\n";
	$self->stop_instances;
	warncolor "#{red}annotation scan#r\n";
	$self->annotation->scan;
	$self->start_instances;
}

# Останавливает инстансы и ждёт их завершения
sub stop_instances {
	my ($self) = @_;
	warncolor "#{red}stop_instances#r\n";
	for my $instance (@{$self->instances}) {
		$instance->stop;
	}
	$self
}

# Запустить инстансы
sub start_instances {
	my ($self) = @_;
	warncolor "#{red}start_instances#r\n";
	for my $instance (@{$self->instances}) {
		$instance->start;
	}
	$self
}

# Выбирает наименее загруженный инстанс для запроса
sub select_instance {
	my ($self) = @_;

	my @ready_instances = grep $_->is_ready, @{$self->instances};
	
	unless(@ready_instances) {
		warncolor "#{red}no ready instances#r\n";
		$self->is_ready_timeout(1), async {
			warncolor "#{red}sleep instance#r\n";
			Coro::AnyEvent::sleep($self->ready_timeout);
			$self->is_ready_timeout(0);
			$self->ready->broadcast;
		} unless $self->is_ready_timeout;
		$self->ready->wait;
		@ready_instances = grep $_->is_ready, @{$self->instances};
	}
	
	my $instance = (sort { $a->count_requests <=> $b->count_requests } @ready_instances)[0];
	
	warncolor "#{red}get instance#r\n";
	
	$instance
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Action::Http::Proxy - балансир (HTTP-прокси) для разработки, перезапускающий воркеры при изменении кода

=head1 SYNOPSIS

Файл etc/annotation/method.ann:

	Tst::Action::Index#head,0=GET / „Index page”

Файл lib/Tst/Action/Index.pm:

	package Tst::Action::Index;
	use Aion;
	with qw/Aion::Action/;
	
	#@method GET / „Index page”
	sub head { "Index" }
	
	1;

Файл etc/annotation/run.ann:

	Aion::Action::Http::Proxy#run,0=http:dev „Запуск HTTP-сервера разработки”
	Aion::Action::Http::Action#run,0=http:action „Запуск HTTP-сервера”

Код:

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
	
	$response->status_line # => 200 OK
	$response->decoded_content # => Index
	
	$response = $ua->get("http://127.0.0.1:$port/x");
	$response->status_line # => 404 Not Found
	
	replace { s!GET /!GET /x!; s/"Index"/"Live"/ } 'lib/Tst/Action/Index.pm';
	cede;
	
	$response = $ua->get("http://127.0.0.1:$port");
	$response->status_line # => 404 Not Found
	
	$response = $ua->get("http://127.0.0.1:$port/x");
	$response->status_line # => 200 OK
	$response->decoded_content # => Live

=head1 DESCRIPTION

C<Aion::Action::Http::Proxy> прозрачный прокси-сервер с автоматическим восстановлением отказов (Auto-Healing) и горячей перезагрузкой (Live Reload) серверов в дочерних процессах (C<Aion::Action::Http::Action>). Обеспечивает высокую доступность, перенаправляя трафик на пул воркеров, и гарантирует идемпотентность состояний: при сбое процесса или изменении файловой системы (watch) инициирует бесшовный рестарт дочерних сервисов без потери соединений.

Он следит за изменением кодовой базы и перезапускает в этом случае сервера C<action>. 

Запросы от браузера он пропускает через себя и задерживает их, если в этот момент все C<action> перезагружаются.

=head1 FEATURES

=head2 port

Порт на котором стартует сервер. Значение по умолчанию берётся из конфига C<PORT>.

=head2 dev_port

Порт на котором стартует дочерний сервер для разработки (C<action>). Значение по умолчанию берётся из конфига C<< Aion::Action::Http::Action-E<gt>PORT >>.

=head2 host

Хост на котором стартует сервер. Значение по умолчанию берётся из конфига C<HOST>.

=head2 watch

Список каталогов для отслеживания.

	use Aion::Action::Http::Proxy;
	my $proxy = Aion::Action::Http::Proxy->new;
	
	$proxy->watch # --> ['lib']

=head2 watch_filter

Регулярка или подпрограмма для подходящих путей.

	use Aion::Action::Http::Proxy;
	my $proxy = Aion::Action::Http::Proxy->new;
	
	$proxy->watch_filter # -> qr/\.(pm|yml)$/n

=head2 annotation

Менеджер аннотаций.

	use Aion::Action::Http::Proxy;
	my $proxy = Aion::Action::Http::Proxy->new;
	
	ref $proxy->annotation # => Aion::Annotation

=head2 corona

Сервер.

	use Aion::Action::Http::Proxy;
	my $proxy = Aion::Action::Http::Proxy->new;
	
	ref $proxy->corona # => Corona::Server

=head1 SUBROUTINES

=head2 run ()

@run http:dev „Запуск HTTP-сервера разработки”.

=head2 restart (@events)

Обработка изменения кодовой базы.

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Action::Http::Proxy module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
