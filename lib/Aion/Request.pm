package Aion::Request;

use common::sense;

use Encode;


sub new {
	my $class = shift;
	bless {@_}, $class
}

sub method {
	my ($self) = @_;
	$self->{REQUEST_METHOD}
}

sub uri {
	my ($self) = @_;
	$self->{REQUEST_URI}
}

sub host {
	my ($self) = @_;
	$self->{HTTP_HOST}
}

sub referer {
	my ($self) = @_;
	$self->{HTTP_REFERER}
}

sub agent {
	my ($self) = @_;
	$self->{HTTP_USER_AGENT}
}

sub len {
	my ($self) = @_;
	$self->{CONTENT_LENGTH}
}

sub accept {
	my ($self) = @_;
	$self->{accept} //= [split /,/, $self->{HTTP_ACCEPT}];
}

sub accept_json {
	my ($self) = @_;
	scalar $self->{HTTP_ACCEPT} =~ /\bjson\b/i || exists $self->GET->{_json};
}

sub is_ajax {
	my ($self) = @_;
	$self->{is_ajax} //= $self->{HTTP_X_REQUESTED_WITH} eq "XMLHttpRequest"
}

sub path {
	my ($self) = @_;
	$self->{path} //= do {
		my $x = $self->uri =~ m!^(.*?)(?:\?|$)!? _unescape($1): die "Нет пути в uri";
		$x
	};
}

sub param {
	my ($self, $name) = @_;

	my $param = $self->{SLUG}->{$name} // $self->GET->{$name} // $self->POST->{$name};

	$param
}

sub PARAM {
	my ($self) = @_;

	$self->{PARAM} //= { %{$self->POST}, %{$self->GET}, %{$self->SLUG} }
}

sub SLUG {
	my ($self) = @_;
	$self->{SLUG}
}

sub GET {
	my ($self) = @_;
	$self->{GET} //= _parse($self->{QUERY_STRING});
}

sub POST {
	my ($self) = @_;
	$self->{POST} //= do {
		if($self->{CONTENT_LENGTH}) {
			if($self->{CONTENT_TYPE} =~ m!^multipart/form-data;!) {
				$self->_multipart_form_data(\*STDIN, $self->{CONTENT_TYPE})
			} else {
				$self->{CONTENT_LENGTH_READED} = read STDIN, my $buf, $self->{CONTENT_LENGTH};
				_parse($buf)
			}
		}
		else {+{}}
	}
}

sub is_GET {
	my ($self) = @_;
	$self->{REQUEST_METHOD} eq "GET"
}

sub is_POST {
	my ($self) = @_;
	$self->{REQUEST_METHOD} eq "POST"
}

sub COOKIE {
	my ($self) = @_;
	$self->{COOKIE} //= _parse($self->{HTTP_COOKIE}, qr/;\s*/);
}

sub HEADER {
	my ($self) = @_;
	$self->{HEADER} //= +{ map /^HTTP_(.*)$/? (lc($1) => $self->{$_}): (), keys %$self }
}


# Определяет кодировку. В koi8-r и в cp1251 большие и малые буквы как бы поменялись местами, поэтому у правильной кодировки вес будет больше
sub _bohemy {
	my ($s) = @_;
	my $c = 0;
	while($s =~ /[а-яё]+/gi) {
		my $x = $&;
		if($x =~ /^[А-ЯЁа-яё][а-яё]*$/) { $c += length $x } else { $c -= length $x }
	}
	$c
}

# кроме перекодировки ещё и кодировку определяет: utf-8, koi8-r или cp1251
sub unescape { shift; goto &_unescape }
sub _unescape {
	my ($x) = @_;
	{
		no utf8;
		use bytes;
		utf8::encode($x) if utf8::is_utf8($x);
		$x =~ s!%([a-f\d]{2})!chr hex $1!gie;
	}
	eval { $x = Encode::decode_utf8($x, Encode::FB_CROAK) };
	if($@) { # видимо тут кодировка cp1251 или koi8-r
		my $cp = Encode::decode('cp1251', $x);
		my $koi = Encode::decode('koi8-r', $x);
		# выбираем перекодировку в которой меньше больших букв внутри слова
		$x = _bohemy($koi) > _bohemy($cp)? $koi: $cp;
	}

	$x
}


# парсит стандартные параметры
sub parse { shift; goto &_parse }
sub _parse {
	my ($x, $by) = @_;

	$by //= qr/&/;
	$x //= "";
	my $r = {};

	for(split $by, $x) {
		s!\+! !g;
		my ($k, $v) = /=/? ($` => $'): ($_ => 1);
		$k = _unescape($k);
		$v = _unescape($v);

		my ($key) = $k =~ /^([^\[\]]*)/;
		my $box = $r;
		
		while($k =~ /\[([^\[\]]*)\]/g) {
			my $subkey = $1;
			
			if(ref $box eq "ARRAY") {
				$key = @$box if $key eq "";
				$box = $box->[$key] //= ($subkey =~ /^\d*\z/? []: {});
			} else {
				$box = $box->{$key} //= ($subkey =~ /^\d*\z/? []: {});
			}
			
			$key = $subkey;
		}
		
		if(ref $box eq "ARRAY") {
			$key = @$box if $key eq "";
			$box->[$key] = $v;
		} else {
			$box->{$key} = $v;
		}
	}

	$r
}

# multipart/form-data
sub _multipart_form_data {
	my ($self, $stdin, $type) = @_;
	no utf8;
	use bytes;

	local ($_);
	die "Не multipart/form-data!" if $type !~ m!^multipart/form-data;\s*boundary=!i;
	my $boundary = qr/^--$'(--)?\r?\n/;
	my $param = {};
	my $is_val = 0;
	my $file_name;
	my $content_type;
	my @buf;

	my ($head, $is_head);
	my ($name, $encoding) = ("");

	# TODO: для сокетов - считывать CONTENT_LENGTH байт. EOF есть только в CGI
	my @lines;

	while(defined($_ = readline $stdin)) {
		$self->{CONTENT_LENGTH_READED} += length $_;
		push @lines, $_;
		if($_ =~ $boundary) {
			my $the_end = $1;
			@buf = "" if @buf == 0;
			$buf[$#buf] =~ s/\r?\n//;
			if($name ne "") {

				my $body = join '', @buf;

				my $val = $is_val? do {
					#$content_type =~ /charset=utf-8/;
					$body
				}: {file => $body, filename => $file_name, type => $content_type, head => $head};

				# устанавливается и для параметров
				if($name =~ s!\[\]$!!) {
					push @{$param->{$name}}, $val;
				}
				else {
					#print STDERR "name new: $name\n";
					$param->{$name} = $val;
				}

			}
			last if $the_end;
			$is_head = 1;
			$head = {};
			@buf = ();
			$is_val = 0;
			$name = "";
			$file_name = "";
			$content_type = "";
			#$encoding = "";
		} elsif($is_head && /^\r?$/) {
			$is_head = undef;
		} elsif($is_head) {
			$name = $1, $is_val = !/\bfilename=['"]?([^'";]+)/i, $file_name=$1 if /^Content[-_]Disposition: .*?\bname=['"]?([^\s'";]+)/i;
			$content_type = $1 if /^Content[-_]Type:\s*(.*?)\s*$/i;
			#$encoding = $1 if /Content-Transfer-Encoding: ([\w-]+)/;
			s/\r?\n//;
			/: /; $head->{$`} = $';
		} else {
			push @buf, $_;
		}
	}

	# в параметрах
	return $param;
}

# Инициализация запроса
sub init {
	my ($self) = @_;

	if(!exists $ENV{REQUEST_URI}) {

		# это - консоль!
		my $uri = $ARGV[0] // ($0 =~ m!([^/])$!? "/cgi-bin/$1": undef);

		%$self = (
			REQUEST_URI => $uri,
			QUERY_STRING => ($uri =~ /\?(.*)/? $1: ""),
			REQUEST_METHOD => "GET",
			HTTP_ACCEPT => "*/*",
			%ENV,
		);
	} else {
		%$self = %ENV;
	}

	$self->{SLUG} = {};

	$self->{CONTENT_LENGTH_READED} = 0;
	if($self->{CONTENT_LENGTH}) {
		binmode STDIN, ":raw";
	} else {
		$self->{POST} = {};
	}

	$self
}

sub DESTROY {
	my ($self) = @_;

	my $len = $self->{CONTENT_LENGTH} - $self->{CONTENT_LENGTH_READED};
	# смещаем позицию на $len байт вперёд. seek не действует
	my $x = 1024*1024*6;
	while($len > 0) {
		$len -= read STDIN, my $buf, $len > $x? $x: $len;
	}
}

1;