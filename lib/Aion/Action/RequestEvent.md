# NAME

Aion::Action::RequestEvent - событие для http-сервера

# SYNOPSIS

```perl
use Aion::Action::RequestEvent;

my $event = Aion::Action::RequestEvent->new;

ref $event # => Aion::Action::RequestEvent
```

# DESCRIPTION

Данное событие содержит всю информацию необходимую для обработки http-запроса и формирования ответа. А именно: запрос, ответ, сервер и исключения появившиеся на этапах выполнения и обработки ответа.

# FEATURES

## server

http-сервер типа `Aion::Action::Http::Action`.

## request

Запрос типа `Plack::Request`.

## response

Ответ типа `Plack::Response`. До формирования ответа заполняется сервером временным ответом с кодом `102 Processing`.

## exception

Исключение, которое могло произойти во время выполнения.
А именно: события drop и привязанного к роуту экшена.
Может быть любого типа.

## exception_code

Исключение, которое могло произойти во время событий nnn, nxx и code.
Может быть любого типа.

# SUBROUTINES

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Action::RequestEvent module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
