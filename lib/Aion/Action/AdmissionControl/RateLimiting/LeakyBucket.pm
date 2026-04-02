package Aion::Action::AdmiossionControl::RateLimiting::LeakyBucket;

use common::sense;

use Guard qw/guard/;
use HTTP::Exception;

use config {
	MAX_REQUESTS => 1000,
	MAX_PARALLEL_REQUESTS => 13,
};

use Aion;

# Запросы
has requests => (is => 'rw', isa => Int, default => 0);

# Ограничение на количество одновременно обрабатываемых запросов
has semaphore => (is => 'ro', default => Coro::Semaphore->new(MAX_PARALLEL_REQUESTS));

#@listen Aion::Action::RequestEvent#drop
sub drop {
	my ($self, $event) = @_;

	HTTP::Exception::TOO_MANY_REQUESTS->throw("¯\_(+_+)_/¯ Too Many Request") if $self->{requests} > MAX_REQUESTS;
	
	$self->{requests}++;
    $self->semaphore->down;
}


#@listen Aion::Action::RequestEvent#leave
sub leave {
	my ($self) = @_;
	
	$self->semaphore->up;
	$self->{requests}--;
}

1;
