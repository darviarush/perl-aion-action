package Aion::Action::Session;
use common::sense;

use Aion::Format qw/from_radix to_radix/;
use Aion::Query qw/query_id query_do/;

require Exporter;
our @EXPORT = our @EXPORT_OK = grep {
	*{$Aion::Action::Session::{$_}}{CODE} && !/^(_|(NaN|import)\z)/n
} keys %Aion::Action::Session::;

# создаёт куку и пользователя при первом вызове, возвращает user_id
sub auth() {
	return $::USER_ID if $::USER_ID;

	our $q;
	my $s = $q->COOKIE->{s};
	if(defined $s) {
		$::USER_ID = query_id "user", session=>from_radix($s, 62);
		undef $s if !$::USER_ID;
	}

	if(!defined $s) { # создаём куку и пользователя
		my $c;
		do {
			# perl не работает с 64-битными числами. Только с 40-битными, остальные биты уходят на флаги.
			# В результате следует перевод на
			$s = join "", map { to_radix(int rand(0xFFFF+1), 16) } 1..4;
			$s = from_radix($s, 16);
			$::SESSION_COOKIE = to_radix($s, 62);
			eval { query_do "INSERT INTO user(session) VALUES ($s)" };
		} while($@ && $c++ < 5);
		die if $@;
		$::USER_ID = LAST_INSERT_ID;
	}
	else {
		$::USER_ID
	}
}

# не создаёт куку и пользователя, а просто возвращает user_id, если пользователь уже есть
sub is_auth() {
	return $::USER_ID if $::USER_ID;

	our $q;
	my $s = $q->COOKIE->{s};
	$::USER_ID = query_id "user", session => from_radix($s, 62) if defined $s;

	$::USER_ID
}

# Переключается на другого пользователя
sub relogin_auth($) {
	my ($user_id) = @_;
	
	my $session = query_scalar "SELECT session FROM user WHERE id=:id", id=>$user_id;
	
	die "Нет пользователя $user_id" if !defined $session;
	
	$::USER_ID = $user_id;
	$::SESSION_COOKIE = to_radix($session, 62);
	return;
}

1;