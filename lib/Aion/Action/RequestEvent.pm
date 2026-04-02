package Aion::Action::RequestEvent;

use common::sense;

use Aion;

# http-сервер
has server => (is => 'ro*', isa => 'Aion::Action::Http::Action');

# Запрос
has request => (is => 'ro', isa => 'Plack::Request');

# Ответ
has response => (is => 'rw', isa => 'Plack::Response');

# Исключение, которое могло произойти во время выполнения
has exception => (is => 'rw');

# Исключение, которое могло произойти во время события code
has exception_code => (is => 'rw');

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Action::RequestEvent - событие для http-сервера

=head1 SYNOPSIS

	use Aion::Action::RequestEvent;
	
	my $event = Aion::Action::RequestEvent->new;
	
	ref $event # => Aion::Action::RequestEvent

=head1 DESCRIPTION

Данное событие содержит всю информацию необходимую для обработки http-запроса и формирования ответа. А именно: запрос, ответ, сервер и исключения появившиеся на этапах выполнения и обработки ответа.

Объект данного класса проходит несколько событий сгруппированных по ловушкам исключений: 

=over

=item * C<drop> – запрос «капнул».

=item * C<MyClass.my_sub.drop> – если роут распознан, то срабатывает экшн с его классом, методом и словом C<drop> через точку.

=item * C<MyClass.my_sub.leave> – после экшена.

=back

Если тут происходит исключение, то оно записывается в свойство C<exception>.

=over

=item * C<200> – сформирован ответ с данным кодом.

=item * C<2xx> – ответ с кодами в данном диапазоне.

=item * C<code> – ответ.

=back

Если тут происходит исключение, то оно записывается в свойство C<exception_code>.

=over

=item * C<leave> – ответ покидает сервер и отправляется пользователю.

=back

Если тут происходит исключение, то возвращается сырой ответ C<500>.

=head1 FEATURES

=head2 server

http-сервер типа C<Aion::Action::Http::Action>.

=head2 request

Запрос типа C<Plack::Request>.

=head2 response

Ответ типа C<Plack::Response>. До формирования ответа заполняется сервером временным ответом с кодом C<102 Procession>.

=head2 exception

Исключение, которое могло произойти во время выполнения.
А именно: события drop и привязанного к роуту экшена.
Может быть любого типа.

=head2 exception_code

Исключение, которое могло произойти во время событий nnn, nxx и code.
Может быть любого типа.

=head1 SUBROUTINES

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Action::RequestEvent module is copyright © 2026 Yaroslav O. Kosmina. Rusland. All rights reserved.
