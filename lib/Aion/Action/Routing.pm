package Aion::Action::Routing;

use common::sense;
use List::Util qw//;

use config INI => 'etc/annotation/method.ann';

use Aion;

# Путь к собранным из аннотаций методам
has ini => (is => 'ro', isa => Str, default => INI);

# Список методов
has methods => (is => 'ro', isa => ArrayRef[Tuple[RegexpRef, HashRef[Dict[pkg => Str, sub => Str, remark => Str]], NonEmptyStr]], default => sub {
	my ($self) = @_;
	my %method;
	
	if(defined $self->ini and -e $self->ini) {
		open my $f, "<:utf8", $self->ini or die "Not open ${\$self->ini}";
		while(<$f>) {
			close($f), die "${\$self->ini}:$. corrupt!" unless /^([\w:]+)#(\w*),\d+=(\w+)\s+(\S+)\s+(.*)$/;
			my ($pkg, $sub, $method, $route, $remark) = ($1, $2, $3, $4, $5);
			my $override = $method{$route}{$method};
			warn "Override $method $route $remark on $override->{pkg}\#$override->{sub} of $pkg\#$sub" if $override;
			$method{$route}{$method} = {
				pkg => $pkg,
				sub => $sub,
				remark => $remark,
			};
		}
		close $f;
	}

	[sort { $a->[2] cmp $b->[2] } List::Util::pairmap {
		my $re = (my $x = $a) =~ s/\{([a-z_]\w*)\}/\(?<$1>[^\/]*\)/gir;
		[qr/^(?:$re)\z/n => $b => $x]
	} %method]
});

# Находит соответствующий роут
sub trace {
	my ($self, $method, $path) = @_;

	for my $stash (@{$self->methods}) {
		if($path =~ $stash->[0]) {
			my $route = $stash->[1]{$method};
			return $route, {%+};
		}
	}
	
	return undef, undef;
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Action::Routing - http router

=head1 SYNOPSIS

File etc/annotation/method.ann:

	MyApp#index,0=GET	/hello/{name}	„Say hello”
	MyApp#show,0=POST	/user/{id}		„Show user”

Code:

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

=head1 DESCRIPTION

Router for obtaining a route by URL path. It also allows you to get CNC (human-readable URLs) from the path.

=head1 CONFIGURABLE CONSTANTS

=head1 INI

Path to methods collected from annotations.

=head1 FEATURES

=head2 ini

Path to methods collected from annotations. Default is C<INI>.

=head2 methods

List of methods.

=head1 SUBROUTINES

=head2 trace ($method, $path)

Finds the corresponding route.

Returns a list of two items: a hash with a description of the method and a hash of the CNC recognized in the path.

If the first item is C<undef>, and the second is not C<undef>, but a hash, then this means that the route was found, but there is no method ($method`) in it.

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Action::Routing module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
