package Aion::Routing;
# Роутинг

use common::sense;
use Aion::View;

# Путь к файлу роутинга
has path => (is => "ro", isa => Str, default => $main_config::routers_path);

# Роутеры из файла
has routers => (is => "rw", isa => ArrayRef, default => sub {
	my ($self) = @_;
	(from_json read_file $self->path)->{routers}
});

# Находит соответствующий роут
# Метод должен быть с большой буквы
# Третий параметр - slugs
sub route {
	my ($self, $path) = @_;
	
	my $routers = $self->routers;
	for(@$routers) {
		return $_, {%+} if $path =~ /$_->{path}/;
	}
	
	return;
}

1;