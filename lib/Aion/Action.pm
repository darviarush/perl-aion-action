package Aion::Action;
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

our $VERSION = "0.0.0-prealpha";

use Aion;

use config ALLOW_METHODS => [qw/GET POST PUT PATCH DELETE/];

# in => 'path|query|data|cookie|header' — откуда брать значение: из урла, из GET-параметров, из тела запроса, куки или заголовка (подчёрк будет преобразован в тире).
# from => 'POST PUT' — через пробел вводятся методы из которых вводить. Регистр верхний.
# Если указан in, но не указан from, то ввод осуществляется из любых методов.

our @DEFAULT_PARAM = qw/path query data/;
our %PARAM = map $_ => 1, @DEFAULT_PARAM, qw/header cookie/;

aspect in => sub {
    my ($pkg, $name, $in, $construct, $feature) = @_;

    return $feature->{in} = \@DEFAULT_PARAM if $in eq 1;

    $in = [split /\s+/, $in] if !ref $in;
    for (@$in) {
        die "has $name. Not exists in => `$_`. Use " . join ", ", sort keys %PARAM unless exists $PARAM{$_};
    }
    $feature->{in} = $in;
};

aspect from => sub {
    my ($pkg, $name, $from, $construct, $feature) = @_;
    $from = [split /\s+/, $from] unless ref $from;
    for(@$from) {
        die "has $name. Not exists from => `$_`. Use " . join ", ", @{&ALLOW_METHODS} unless  ~~ ALLOW_METHODS;
    }

    $feature->{from} = $from;
};

1;