# NAME

Aion::Action::AdmissionControl::RateLimiting::LeakyBucket - 

# SYNOPSIS

Файл .config.pm:
```perl

```

Код:
```perl
use aliased 'Aion::Action::AdmissionControl::RateLimiting::LeakyBucket' => 'LeakyBucket';

my $leakyBucket = LeakyBucket->new;


```

# DESCRIPTION

Данный класс реализует алгоритм "Дырявое ведро" для ограничения одновременно выполняющихся запросов к http-серверу.

# FEATURES

## requests

Количество пришедших запросов (выполняющихся или в очереди).

## semaphore

Ограничение на количество одновременно обрабатываемых запросов.

```perl
my $ = Aion::Action::AdmissionControl::RateLimiting:: LeakyBucket->new;

$->semaphore # -> .5
```

# SUBROUTINES

## drop ($event)

@listen Aion::Action::RequestEvent#drop.

```perl
my $ = Aion::Action::AdmissionControl::RateLimiting:: LeakyBucket->new;
$->drop($event)  # -> .3
```

## leave ()

@listen Aion::Action::RequestEvent#leave.

```perl
my $ = Aion::Action::AdmissionControl::RateLimiting:: LeakyBucket->new;
$->leave  # -> .3
```

# INSTALL

For install this module in your system run next [command](https://metacpan.org/pod/App::cpm):

```sh
sudo cpm install -gvv Aion::Action::AdmissionControl::RateLimiting:: LeakyBucket
```

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Action::AdmissionControl::RateLimiting:: LeakyBucket module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
