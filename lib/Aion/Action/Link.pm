package Aion::Action::Link;

use common::sense;

use Aion;

# Роутинг
has routing => (is => 'ro', isa => 'Aion::Action::Routing', eon => 1);

# Генерирует ссылку
sub generate {
	my ($self, $action, $slug) = @_;

	my ($via, $pkg, $sub) = $action =~ /^(?:(\w+)\s+)?([\w:]+)#(\w+)$/ or die "Action `$action` corrupt!";
	$via //= 'GET';

	my $path;
	for my $stash (@{$self->routing->methods}) {
		my ($re_, $action, $path_) = @$stash;
		my $route = $action->{$via};
		$path = $path_, last if $route and $route->{pkg} eq $pkg and $route->{sub} eq $sub;
	}

	die "$via $pkg#$sub not found!" unless $path;
	
	$path =~ s{\{(\w+)\}}{$slug->{$1} // die "$1 not slug in $path!"}ge;
	$path
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Action::Link - генератор ссылок по роуту

=head1 SYNOPSIS

Файл etc/annotation/method.ann:

	MyApp#index,0=GET	/hello/{name}	„Say hello”
	MyApp#show,0=POST	/user/{id}		„Show user”

Код:

	use Aion::Action::Link;
	
	my $link = Aion::Action::Link->new;
	
	$link->generate('MyApp#index', {name => 'World'}) # => /hello/World
	$link->generate('POST MyApp#show', {id => 123})   # => /user/123
	
	$link->generate('MyApp', {})                           # @-> Action `MyApp` corrupt!
	$link->generate('MyApp#show', {})                      # @-> id not slug in /user/{id}!
	$link->generate('POST MyApp#index', {name => 'World'}) # @-> POST MyApp#index not found!

=head1 DESCRIPTION

Генерирует ссылку по роуту находя её по классу и методу к которым привязан обработчик с помощью аннотации C<@method>.

=head1 FEATURES

=head2 routing

Роутинг.

=head1 SUBROUTINES

=head2 generate ($action, $slug)

Генерирует ссылку по параметрам:

=over

=item * C<$action> – строка формата C<$pkg#$method> или C<$via $pkg#$method>. В первом случае C<$via> принимаеться за C<GET>.

=item * C<$slug> – хеш с ЧПУ для вставки в параметры пути.

=back

Если к одному методу инстанса привязано несколько обработчиков, то будет выбран первый согласно сортировке роутов по возрастанию.

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Action::Link module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
