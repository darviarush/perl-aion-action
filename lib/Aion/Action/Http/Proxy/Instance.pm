package Aion::Action::Http::Proxy::Instance;
# Представитель http-сервера в прокси

use common::sense;

use Aion::Format qw/warncolor/;
use AnyEvent qw//;
use AnyEvent::Util qw/run_cmd/;
use Coro;

use config {
	READY_TIMEOUT => 10, # В секундах
	READY_SLEEP => 0.1, # Шаг, сколько спать между проверками
};

use Aion;

# Владелец
has proxy => (is => 'ro+*', isa => 'Aion::Action::Http::Proxy');

# Порт сервера
has port => (is => 'ro+', isa => PositiveInt);

# pid сервера
has pid => (is => 'rw', isa => PositiveInt, default => 0);

# Содержит condvar события завершения сервера
has cv => (is => 'rw');

# Сервер готов принимать запросы
has is_ready => (is => 'rw', isa => Bool, default => 0);

# Количество запросов
has count_requests => (is => 'rw', isa => PositiveInt, default => 0);

# Таймаут готовности сервера
has ready_timeout => (is => 'ro', isa => PositiveNum, default => READY_TIMEOUT);

# Сколько секунд ждать между проверками
has ready_sleep => (is => 'ro', isa => PositiveNum, default => READY_SLEEP);

# Сервер жив
sub is_alive {
	my ($self) = @_;
	$self->pid && kill 0, $self->pid
}

# Запустить
sub start {
	my ($self) = @_;
	
	die "Action on port $self->{port} is alive" if $self->is_alive;

	warncolor "#{blue}Instance on port #{red}%s #{blue}start#r\n", $self->port;
	
	my $action = 'Aion::Action::Http::Action';
	$self->{cv} = run_cmd
		[$^X, "-M$action", '-e', "$action->new(port => ${\$self->port})->run"],
		'$$' => \$self->{pid},
	;
	
	# родитель
    $self->count_requests(0)->is_ready(0);

    # асинхронная проверка готовности
    async { $self->check_ready };
    
    $self
}

# Проверить, что воркер начал отвечать
sub check_ready {
    my ($self) = @_;
    my $ua = $self->proxy->user_agent;

    warncolor "#{yellow}check_ready#r\n";
    for(my $i = 0; $i < $self->{ready_timeout}; $i += $self->{ready_sleep}) {
        my $res = $ua->head("http://127.0.0.1:$self->{port}");
        if ($res && $res->is_success) {
            warncolor "#{green}Instance on port %s is ready#r\n", $self->port;
            $self->is_ready(1)->proxy->ready->broadcast;
            return;
        }
        Coro::AnyEvent::sleep($self->{ready_sleep});
    }
    warncolor "#{yellow}Instance on port %s not ready after %s seconds#r\n", $self->port, $self->ready_timeout;

    # Пусть его перезагрузит процесс
    $self->is_ready(1)->proxy->ready->broadcast
}

# Послать сигнал на остановку сервера
sub stop {
	my ($self) = @_;

	$self->is_ready(0);
	
	return $self unless $self->is_alive;

	warncolor "#{red}Instance on port $self->{port} kill INT#r\n";
	kill 'INT', $self->pid;

	$self
}

# Ожидать завершения и вернуть сигнал
sub awaiting_completion {
	my ($self, $timeout, $step) = @_;
	
	return undef unless $self->is_alive;
	
	$timeout //= 5;
	$step //= 0.1;
	
	async {
		for(my $i = 0; $self->is_alive && $i < $timeout; $i += $step) {
			Coro::AnyEvent::sleep $step;
		}
		
		kill 'KILL', $self->pid if $self->is_alive;
	};
	
	$self->{cv}->recv
} 

# Рестартует инстанс
sub restart {
	my ($self) = @_;
	$self->stop;
	$self->start
}

1;
