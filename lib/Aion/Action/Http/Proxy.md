# NAME

Aion::Action::Http::Proxy - балансир (HTTP-прокси) для разработки, перезапускающий воркеры при изменении кода

# SYNOPSIS

Файл etc/annotation/method.ann:
```text
Tst::Action::Index#head,0=GET / „Index page”
```

Файл lib/Tst/Action/Index.pm:
```perl
package Tst::Action::Index;
use Aion;
with qw/Aion::Action/;

#@method GET / „Index page”
sub head { "Index" }

1;
```

Файл etc/annotation/run.ann:
```text
Aion::Action::Http::Proxy#run,0=http:dev „Запуск HTTP-сервера разработки”
Aion::Action::Http::Action#run,0=http:action „Запуск HTTP-сервера”
```

Код:
```perl
use Coro;
use LWP::UserAgent;
use Coro::LWP;
use Aion::Fs qw/replace/;
use AnyEvent::Util qw/run_cmd/;

my $port = 3075;
my $dev_port = 3076;

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
```

# DESCRIPTION

`Aion::Action::Http::Proxy` прозрачный прокси-сервер с автоматическим восстановлением отказов (Auto-Healing) и горячей перезагрузкой (Live Reload) серверов в дочерних процессах (`Aion::Action::Http::Action`). Обеспечивает высокую доступность, перенаправляя трафик на пул воркеров, и гарантирует идемпотентность состояний: при сбое процесса или изменении файловой системы (watch) инициирует бесшовный рестарт дочерних сервисов без потери соединений.

Он следит за изменением кодовой базы и перезапускает в этом случае сервера `action`. 

Запросы от браузера он пропускает через себя и задерживает их, если в этот момент все `action` перезагружаются.

# FEATURES

## port

Порт на котором стартует сервер. Значение по умолчанию берётся из конфига `PORT`.

## dev_port

Порт на котором стартует дочерний сервер для разработки (`action`). Значение по умолчанию берётся из конфига `Aion::Action::Http::Action->PORT`.

## host

Хост на котором стартует сервер. Значение по умолчанию берётся из конфига `HOST`.

## watch

Список каталогов для отслеживания.

```perl
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

$proxy->watch # --> ['lib']
```

## watch_filter

Регулярка или подпрограмма для подходящих путей.

```perl
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

$proxy->watch_filter # -> qr/\.(pm|yml)$/n
```

## annotation

Менеджер аннотаций.

```perl
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

ref $proxy->annotation # => Aion::Annotation
```

## corona

Сервер.

```perl
use Aion::Action::Http::Proxy;
my $proxy = Aion::Action::Http::Proxy->new;

ref $proxy->corona # => Corona::Server
```

# SUBROUTINES

## run ()

@run http:dev „Запуск HTTP-сервера разработки”.

## restart (@events)

Обработка изменения кодовой базы.

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Action::Http::Proxy module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
