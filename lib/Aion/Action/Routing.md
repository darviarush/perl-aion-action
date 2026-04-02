!ru:en
# NAME

Aion::Action::Routing - http-роутер

# SYNOPSIS

Файл etc/annotation/method.ann:
```text
MyApp#index,0=GET	/hello/{name}	„Say hello”
MyApp#show,0=POST	/user/{id}		„Show user”
```

Код:
```perl
use Aion::Action::Routing;

my $routing = Aion::Action::Routing->new;
my ($method, $slug) = $routing->trace('GET', '/hello/World');

my %method = (
	pkg => 'MyApp',
	sub => 'index',
	remark => '„Say hello”',
);

$method # --> \%method
$slug   # --> {name => 'World'}

my ($not_found, $slug_found) = $routing->trace('POST', '/hello/World');
$not_found  # -> undef
$slug_found # --> {name => 'World'}
```

# DESCRIPTION

Роутер для получения по URL-пути роута. Так же позволяет получить из пути ЧПУ (человекопонятные урлы).

# CONFIGURABLE CONSTANTS

# INI

Путь к собранным из аннотаций методам.

# FEATURES

## ini

Путь к собранным из аннотаций методам. По умолчанию – `INI`.

## methods

Список методов.

# SUBROUTINES

## trace ($method, $path)

Находит соответствующий роут.

Возвращает список из двух пунктов: хеша с описанием метода и хеша с ЧПУ распознанных в пути.

Если первый пункт `undef`, а второй не `undef`, а хеш, то это значит, что роут найден, но метода (`$method`) в нём нет.

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Action::Routing module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
