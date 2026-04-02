# NAME

Aion::Action::Link - генератор ссылок по роуту

# SYNOPSIS

Файл etc/annotation/method.ann:
```text
MyApp#index,0=GET	/hello/{name}	„Say hello”
MyApp#show,0=POST	/user/{id}		„Show user”
```

Код:
```perl
use Aion::Action::Link;

my $link = Aion::Action::Link->new;

$link->generate('MyApp#index', {name => 'World'}) # => /hello/World
$link->generate('POST MyApp#show', {id => 123})   # => /user/123

$link->generate('MyApp', {})                           # @-> Action `MyApp` corrupt!
$link->generate('MyApp#show', {})                      # @-> id not slug in /user/{id}!
$link->generate('POST MyApp#index', {name => 'World'}) # @-> POST MyApp#index not found!
```

# DESCRIPTION

Генерирует ссылку по роуту находя её по классу и методу к которым привязан обработчик с помощью аннотации `@method`.

# FEATURES

## routing

Роутинг.

# SUBROUTINES

## generate ($action, $slug)

Генерирует ссылку по параметрам:

* `$action` – строка формата `$pkg#$method` или `$via $pkg#$method`. В первом случае `$via` принимаеться за `GET`.
* `$slug` – хеш с ЧПУ для вставки в параметры пути.

Если к одному методу инстанса привязано несколько обработчиков, то будет выбран первый согласно сортировке роутов по возрастанию.

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Action::Link module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
