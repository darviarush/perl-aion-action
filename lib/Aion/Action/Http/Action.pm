package Aion::Action::Http::Action;
# Сервер http

use common::sense;

use Aion::Action;
use Aion::Action::Http::Aurora;
use Aion::Action::RequestEvent;
use Aion::Annotation;
use Aion::Carp;
use Aion::Format qw/warncolor/;
use Aion::Format::Json qw/to_json/;
use Aion::Fs qw/include/;
use AnyEvent qw//;
use HTTP::Exception;
use HTTP::Status qw//;
use List::Util qw//;
use Scalar::Util qw//;
use Plack::Response;
use Plack::Request;
use Log::Any qw//;

use config {
	NAME => "aion-action",
	HOST => "localhost",
	PORT => 3000,
};

use Aion;

with 'Aion::Run';

# Имя сервера
has name => (is => 'ro', isa => Str, arg => '-n', default => NAME);

# Хост на котором стартует сервер
has host => (is => 'ro', isa => Str, arg => '-h', default => HOST);

# Порт на котором стартует сервер
has port => (is => 'ro', isa => PositiveInt, arg => '-p', default => PORT);

# Запросы
has action => (is => 'ro', isa => HashRef['Aion::Action::RequestEvent'], lazy => 0, default => sub {+{}});

# Роутинг
has routing => (is => 'ro', isa => 'Aion::Action::Routing', eon => 1);

# Эмиттер
has emitter => (is => 'ro', isa => 'Aion::Emitter', eon => 1);

# Логгер
has log => (is => 'ro', default => Log::Any->get_logger(category => 'http'));

# Для хранения обработчиков сигналов остановки сервера
has shutdown_watchers => (is => 'ro?!', isa => ArrayRef['AnyEvent::Signal']);

# Сервер
has aurora => (is => 'ro', isa => 'Aion::Action::Http::Aurora', default => sub {
	my ($self) = @_;
	Aion::Action::Http::Aurora->new(
		name  => $self->name,
		host  => $self->host,
		port  => $self->port,
		app   => sub { $self->request(@_) },
        after => sub { my ($res, $env) = @_; unshift @{$res->[1]}, server => $self->server },
    )
});

#@run http:action „Запуск HTTP-сервера”
sub run {
    my ($self) = @_;
    local $|=1;
	warncolor "#green%s#r started on port #red%s#r\n", ref $self, $self->port;
	$Coro::current->on_destroy(sub {
		warncolor "#{red}destroy %s!#r\n", $self->{port};
	});
	
	$self->{shutdown_watchers} = [map AnyEvent->signal(signal => $_, cb => sub { $self->stop }), qw/INT TERM QUIT/];

	warncolor "#blue%s#r set watchers\n", $self->port;

	$self->emitter->emit($self, 'start');
	$self->aurora->accept();
	$self->emitter->emit($self, 'stop');
	
	warncolor "#{red}%s#r on port #{green}%s #{red}stopped!#r\n", ref $self, $self->port;
}

# Запрос к серверу
sub request {
	my ($self, $env) = @_;

	# Читаем content-length и body
	my $q = Plack::Request->new($env);
	warncolor "#cyan%s#r #magenta%s#r\n", $q->method, $q->path;

	my $event = Aion::Action::RequestEvent->new(
		server => $self,
		request => $q,
		response => Plack::Response->new(HTTP::Status::HTTP_PROCESSING, [], '0~0 Processing...'),
	);
	$self->{request}{Scalar::Util::refaddr $event} = $event;

	eval {
		#HTTP::Exception::NON_AUTHORITATIVE_INFORMATION->throw("[O.o] - O RLY? ${\$q->remote_host}" if $self->dev && $q->address !~ /^(127.0.0.1|::1)/;

		$self->emitter->emit($event, 'drop');

		my ($method, $slug) = $self->routing->trace($q->method, $q->path);
	
	    if(!defined $method) {
			die HTTP::Exception::METHOD_NOT_ALLOWED->new(message => "(x(x_(x_x(O_o)x_x)_x)x) Method Not Allowed") if $slug;
	        die HTTP::Exception::NOT_FOUND->new(message => "(-(-_(-_-(O_o)-_-)_-)-) Not Found\n");
	    }
					
		my ($pkg, $sub) = @$method{qw/pkg sub/};

		$self->emitter->emit($event, "$pkg.$sub.drop");

		my $response = include($pkg)->new_from_request($q, $slug)->$sub;
		
		$response = do {
			if(UNIVERSAL::isa($response, 'Plack::Response')) { $response }
			elsif(ref $response eq "HASH") { Plack::Response->new(200, ['Content-Type' => 'application/json; charset=utf-8'], to_json $response) }
			else { Plack::Response->new(200, ['Content-Type' => 'text/html; charset=utf-8'], $response) }
		};
		$event->response($response);
		
		$self->emitter->emit($event, "$pkg.$sub.leave");
	};
	if($@) {
		$event->exception($@);
		$event->response($self->form_error_response($@));		
	}

	eval {
		$self->emitter->emit($event, $event->response->code);
		$self->emitter->emit($event, int($event->response->code / 100) . "xx");
		$self->emitter->emit($event, "code");
	};
	if($@) {
		$event->exception_code($@);
		$event->response($self->form_error_response($@, "code"));
	}


	eval { $self->emitter->emit($event, "leave") };
	if($@) {
		$event->response($self->form_error_response($@, "leave"));
	}
	
	delete $self->{request}{Scalar::Util::refaddr $event};
	$event->response->finalize
}

# Формирует ответ
sub form_error_response {
	my ($self, $exception, $step) = @_;
	
	if(UNIVERSAL::isa($exception, 'Plack::Response')) { $@ }
	elsif(UNIVERSAL::isa($exception, 'HTTP::Exception::Base')) {
		Plack::Response->new($exception->code, [
			exists $exception->{location} ? ('Location' => $exception->location): (),
		], $step? "${\$exception->code} ${\$exception->status_message}": ());
	}
	else {
		Plack::Response->new(500, [], $step? "(」°ロ°)」 500 Internal Server Error on step `$step`": ());
	}
}

# Формирует описание сервера для заголовка server ответа
sub server {
	my ($self) = @_;
	sprintf "action/%s (%s; %s; %s:%s)", Aion::Action->VERSION, $self->{name}, Coro::current->{tid}, $self->{host}, $self->{port}
}

# Мягко останавливает сервер
sub stop {
	my ($self) = @_;
	$self->clear_shutdown_watchers;
	$self->aurora->stop;
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Action::Http::Action - http-сервер с роутингом и событиями

=head1 SYNOPSIS

Файл etc/annotation/method.ann:

	Tst::Action::IndexAction#head,0=GET / „Index page”

Файл lib/Tst/Action/IndexAction.pm:

	package Tst::Action::IndexAction;
	use Aion;
	
	with qw/Aion::Action/;
	
	#@method GET / „Index page”
	sub head {
		my ($self) = @_;
		"it's index"
	}
	
	1;

Код:

	use aliased 'Aion::Action::Http::Action' => 'Action';
	use Coro;
	use LWP::UserAgent;
	use Coro::LWP;
	
	my $port = 3073;
	my $action = Action->new(port => $port);
	async { $action->run };
	cede;
	
	my $response = LWP::UserAgent->new->get("http://127.0.0.1:$port");
	
	$response->is_success # -> 1
	$response->status_line # => 200 OK
	$response->decoded_content # => it's index
	
	$action->stop;

=head1 DESCRIPTION

Сервер основан на http-сервере C<Corona>. Он создаёт легковесный поток (C<Coro>) на каждый запрос.

Список выполняющихся запросов содержится в актуальном состоянии в фиче C<action>.

На запрос формируется объект (C<Aion::Action::RequestEvent>), который проходит несколько событий сгруппированных по ловушкам исключений: 

=over

=item * C<drop> – запрос «капнул».

=item * C<MyClass.my_sub.drop> – если роут распознан, то срабатывает экшн с его классом, методом и словом C<drop> через точку.

=item * C<MyClass.my_sub.leave> – после экшена.

=back

Если тут происходит исключение, то оно записывается в свойство C<exception>.

=over

=item * C<200> – сформирован ответ с данным кодом.

=item * C<2xx> – ответ с кодами в данном диапазоне.

=item * C<code> – ответ.

=back

Если тут происходит исключение, то оно записывается в свойство C<exception_code>.

=over

=item * C<leave> – ответ покидает сервер и отправляется пользователю.

=back

Если тут происходит исключение, то возвращается сырой ответ C<500>.

=head1 FEATURES

=head2 name

Имя сервера. По умолчанию C<NAME> (aion-action).

=head2 host

Хост сервера. По умолчанию C<HOST> (localhost).

=head2 port

Порт на котором стартует сервер. По умолчанию C<PORT> (3000).

=head2 action

Хеш выполняющихся запросов типа C<Aion::Action::RequestEvent>.

=head2 routing

Роутинг.

=head2 emitter

Эмиттер.

=head2 corona

Сервер.

=head1 SUBROUTINES

=head2 run ()

Команда C<@run http:action> для запуска HTTP-сервера.

Мягко останавливается сигналом B<INT>, B<QUIT> или B<TERM>.

Остановить без завершения выполняющихся запросов можно сигналом B<KILL>.

	use Aion::Fs qw/lay/;
	lay "etc/annotation/method.ann", << 'END';
	Tst::Action::SleepAction#sleepping,0=GET /sleep „Sleep”
	END

Файл etc/annotation/run.ann:

	Aion::Action::Http::Action#run,0=http:action „Запуск HTTP-сервера”

Файл lib/Tst/Action/SleepAction.pm:

	package Tst::Action::SleepAction;
	use Aion;
	
	with qw/Aion::Action/;
	
	has sleep_sec => (is => 'ro', isa => Num, in => 'query');
	
	#@method GET /sleep „Sleep”
	sub sleepping {
		my ($self) = @_;
		Coro::AnyEvent::sleep $self->sleep_sec;
		"sleepped"
	}
	
	1;

Код:

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
		$response->status_line # => 200 OK
		$response->decoded_content # => sleepped
		$done->send;
	};
	
	Coro::AnyEvent::sleep 0.3;
	
	kill "TERM", $action_pid # => 1
	
	$done->recv;

=head2 request ($env)

Запрос к серверу.

=head2 form_error_response ($exception, $step)

Формирует ответ.

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Action::Http::Action module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
