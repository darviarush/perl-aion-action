package Aion::Action;
use common::sense;

our $VERSION = "0.0.0";

use config ALLOW_METHODS => [qw/HEAD GET QUERY POST PUT PATCH DELETE OPTIONS/];

use Aion -role;

# in => 'path|query|data|upload|cookie|header|session|server' — откуда брать значение: из урла, из GET-параметров, из тела запроса, куки или заголовка (подчёрк будет преобразован в тире).
# from => 'POST PUT' — через пробел вводятся методы из которых вводить. Регистр верхний.
# Если указан in, но не указан from, то ввод осуществляется из любых методов.

our @DEFAULT_PARAM = qw/path query data/;
our %PARAM = map { $_ => 1 } @DEFAULT_PARAM, qw/header cookie upload session server/;

aspect in => sub {
    my ($in, $feature) = @_;

    return if $in eq 1;
    
    die "has $feature->{name}, in => '$in'. Use ${\join ', ', sort keys %PARAM} or 1" unless exists $PARAM{$in};
    die "has $feature->{name}, in => '$in'. Use: has request" if $in eq 'server' and $feature->{name} ne 'request';
};

aspect from => sub {
    my ($from, $feature) = @_;
    $from = [split /\s+/, $from] unless ref $from;
    for(@$from) {
        die "has $feature->{name}, from => '$_'. Use " . join ", ", @{&ALLOW_METHODS} unless  ~~ ALLOW_METHODS;
    }
};

# Создаёт объект с параметрами запроса
sub new_from_request: Isa(ClassName, Object['Plack::Request'], HashRef[Str] => Me) {
	my ($cls, $q, $slug) = @_;

	my $FEATURE = $Aion::META{$cls}{feature};
	
	my $method = $q->method;
	
	my %param;
	while(my ($name_, $feature) = each %$FEATURE) {
		my $opt = $feature->{opt};
		next if !exists $opt->{in};
		next if exists $opt->{from} && $opt->{from} !~ /\b$method\b/ao;
		
		my $name = $opt->{init_arg} // $name_;
		
        my $value = do { given($opt->{in}) {
            $slug->{$name} // $q->query_parameters->get($name) // $q->body_parameters->get($name) when 1;
            $slug->{$name} when 'path';
            $q->query_parameters->get($name) when 'query';
            $q->body_parameters->get($name) when 'data';
            $q->upload($name) when 'upload';
            $q->header($name) when 'header';
            $q->cookies->get($name) when 'cookie';
            $q->session->get($name) when 'session';
            do {given($name) {
            	$q when 'request';
            }} when 'server';
		}};
		
		$param{$name} = $value if defined $value;
	}

	$cls->new(%param)
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Action - role for creating controllers.

=head1 VERSION

0.0.0

=head1 SYNOPSIS

File lib/Action/HelloAction.pm:

	package Action::HelloAction;
	
	use Aion;
	
	with 'Aion::Action';
	
	# Who should I say hello to?
	has name => (is => 'ro', isa => NonEmptyStr, in => 'path', from => 'GET POST');
	
	#@method GET /hello/{name} „Method for say hello”
	sub say_hello {
		my ($self) = @_;
		return "Hello, ${\$self->name}!";
	}
	
	1;

Code:

	use lib 'lib';
	use Action::HelloAction;
	
	Action::HelloAction->new(name => 'World')->say_hello; # => Hello, World!
	
	use Plack::Request;
	my $env = {
		REQUEST_METHOD => 'GET',
		REQUEST_URI => '/hello/World',
		QUERY_STRING => '',
	};
	
	my $request = Plack::Request->new($env);
	my $slug = {
		name => 'World',
	};
	
	Action::HelloAction->new_from_request($request, $slug)->say_hello; # => Hello, World!

=head1 DESCRIPTION

The B<Aion::Action> role is intended for creating controllers.

It adds an C<in> aspect, which specifies where the parameter is to be taken from. List of places:

=over

=item * path, query, data, upload, cookie, header, session, server and daemon.

=back

And the C<from> aspect, which allows you to specify methods from which to accept parameters. List of methods:

=over

=item * HEAD, GET, QUERY, POST, PUT, PATCH, DELETE and OPTIONS.

=back

You can configure this list through the C<ALLOW_METHODS> config.

=head1 SUBROUTINES/METHODS

=head2 new_from_request ($cls, $request, $slug)

Constructor. Creates an instance of a class based on a request.

The B<$request> parameter must be an instance of C<Plack::Request>.

The B<$slug> parameter must contain the parameters received by the router from the path.

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>
