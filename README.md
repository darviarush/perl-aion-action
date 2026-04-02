[![Actions Status](https://github.com/darviarush/perl-aion-action/actions/workflows/test.yml/badge.svg)](https://github.com/darviarush/perl-aion-action/actions) [![GitHub Issues](https://img.shields.io/github/issues/darviarush/perl-aion-action?logo=perl)](https://github.com/darviarush/perl-aion-action/issues) [![MetaCPAN Release](https://badge.fury.io/pl/Aion-Action.svg)](https://metacpan.org/release/Aion-Action) [![Coverage](https://raw.githubusercontent.com/darviarush/perl-aion-action/master/doc/badges/total.svg)](https://fast2-matrix.cpantesters.org/?dist=Aion-Action+0.0.0)
# NAME

Aion::Action - роль для создания контроллеров.

# VERSION

0.0.0

# SYNOPSIS

Файл lib/Action/HelloAction.pm:
```perl
package Action::HelloAction;

use Aion;

with 'Aion::Action';

# Who should I say hello to?
has name => (is => 'ro', isa => NonEmptyStr, in => 'path', from => 'GET POST');

#@method GET /hello/{name} „Method for say hello”
sub say_hello {
	my ($self) = @_;
	return "Hello, ${\$self->name}!";
}

1;
```

Код:
```perl
use lib 'lib';
use Action::HelloAction;

Action::HelloAction->new(name => 'World')->say_hello; # => Hello, World!

use Plack::Request;
my $env = {
	REQUEST_METHOD => 'GET',
	REQUEST_URI => '/hello/World',
	QUERY_STRING => '',
};

my $request = Plack::Request->new($env);
my $slug = {
	name => 'World',
};

Action::HelloAction->new_from_request($request, $slug)->say_hello; # => Hello, World!
```

# DESCRIPTION

Роль **Aion::Action** предназначена для создания контроллеров.

Она добавляет аспект `in`, который указывает откуда брать параметр. Список мест:

* path, query, data, upload, cookie, header, session, server и daemon.

И аспект `from`, который позволяет указывать методы из которых принимать параметры. Список методов: 

* HEAD, GET, QUERY, POST, PUT, PATCH, DELETE и OPTIONS.

Настроить этот список можно через конфиг `ALLOW_METHODS`.

# SUBROUTINES/METHODS

## new_from_request ($cls, $request, $slug)

Конструктор. Создаёт экземпляр класса на основе запроса.

Параметр **$request** должен быть экземпляром `Plack::Request`.

Параметр **$slug** должен содержать полученные роутером параметры из пути.

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**
