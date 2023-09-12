package Aion::Response;

use common::sense;
use POSIX qw/strftime/;
use query;

sub new {
	my $class = shift;
	bless {@_}, $class;
}

# Статус
sub status {
	my ($self) = @_;
	$self->{status}
}

# Код из статуса
sub code {
	my ($self) = @_;
	int $self->status;
}

# Заголовки
sub header {
	my ($self) = @_;
	$self->{header} //= {};
}

# Хеш кук в формате k => { v=>'значение', path => '/', ... }
sub cookie {
	my ($self) = @_;
	$self->{cookie}
}

# Путь к файлу на диске, вместо контента
sub file {
	my ($self) = @_;
	$self->{file}
}

# Тип контента
sub type {
	my ($self) = @_;
	$self->{type}
}

# Контент
sub content {
	my ($self) = @_;
	$self->{content}
}

# Распечатывает
sub print {
	my ($self, $q) = @_;

	my $content = $self->{content};
	$content = $content->($self) if ref $content eq "CODE";

	$content = $self->create_error($q) if $self->{is_error};

	if(my $file = $self->{file}) {
		open $content, "<", $file or do { $@ = "$file: $!"; return };
	}

	$self->header->{'content-type'} //= $self->{type} // (
		ref $content eq "HASH"? "text/json": ref $content eq 'GLOB'? 'image/png': 'text/html');

	$self->header->{'content-type'} =~ s!^text/[\w-]+\z!$&; charset=utf-8!;

	if(ref $content eq "HASH") {
		query::debug_array($content) if $main_config::dev && @query::DEBUG;
		$content = to_json($content);
	} elsif(!ref $content) {
		if($main_config::dev && @query::DEBUG && $self->header->{'content-type'} =~ m!^text/(plain|html)\b!) {
			no utf8; use bytes;
			my $text = query::debug_text();
			utf8::encode($text) if utf8::is_utf8($text);
			$content = sprintf "%s\n\n<!--\n%s\n-->\n", $content, $text;
			
			$self->header->{'content-length'} = length $content;
		}
	}

	if(defined $content) {
		$self->header->{'content-length'} //= ref $content eq "GLOB"? -s $content: do { use bytes; length $content };
	}

	# Выводим статус и заголовки
	print "Status: ${\$self->code}\n" if $self->{status};
	print "$_: $self->{header}->{$_}\n" for keys %{$self->{header}};

	# Формируем куки
	my $cookie = $self->{cookie};
	$cookie->{s} = { v => $::SESSION_COOKIE, path=>"/", expires => strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time + 60*60*24*365*100)) } if $::SESSION_COOKIE;

	if($cookie) {
		print "Set-Cookie: $_=".delete($cookie->{$_}{v}).do { my $x=$cookie->{$_}; join "", map { "; $_=$x->{$_}" } keys %$x }."\n" for keys %$cookie;
	}

	# Конец заголовков
	print "\n";

	# Отправляем контент
	if(defined $content) {
		if(ref $content eq "GLOB") {
			binmode STDOUT, ":bytes";
			my $buf;
			print $buf while read $content, $buf, $main_config::BLOK_SIZE;
			binmode STDOUT, ":utf8";
			close $content;
		}
		elsif(!utf8::is_utf8($content)) {
			binmode STDOUT, ":bytes";
			print $content;
			binmode STDOUT, ":utf8";
		}
		else {
			print $content;
		}
	}

	$self
}

# Деструктор. Закрываем файл
sub DESTROY {
	my ($self) = @_;

	close $self->{content} if ref $self->{content} eq "GLOB";
}

# Формирует контент ошибки.
sub create_error {
	my ($self) = @_;

	my $detail = $self->{desc};
	$detail =~ s!\n!¶!g;
	$self->header->{detail} = $detail;

	my $status = $self->{status};
	my ($code) = $status =~ /^(\d+)/;

	if($query::q->accept->[0] =~ m!^image/!) {
		my $img = "html/asset/img/$status.png";
		my $f;
		open $f, "<", $img and return $f;
		$self->header->{'content-type'} = "image/svg";
		return qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<text x="0" y="15">$code</text>
</svg>};
	}

	my $page = {
		error => 1,
		head => {
			title => $status,
		},
		code => $code,
		desc => $self->{desc},
		%{$self->{content}},
	};

	if($query::q->accept->[0] =~ m!^text/html\b!) {
		my $pattern = $self->{is_error} == 2? do {
			$status =~ s/^(\d+)\s+(.*)/$2$1/;
			$status =~ s! (\w)!uc $1!ge;
			ucfirst $status
		}: "Error";
		require "Astrobook/Common/HttpError/$pattern.pm";
		my $pkg = "Astrobook::Common::HttpError::$pattern";

		$page = (bless {code => $code, %$self, %{$self->{content}}}, $pkg)->render;
	}

	$page
}

# Конструктор верного ответа
sub ok {
	my ($cls, $content) = splice @_, 0, 2;
	$cls->new(status => "200 OK", content => $content // "hi!", @_)
}

# Формирует ответ для редиректа
sub redirect {
	my ($cls, $location, $content) = splice @_, 0, 3;
	$content //= "308 Permanent Redirect\nTo: $location\n";
	my $redirect = $cls->new(status => "308 Permanent Redirect", content => $content, @_);
	$redirect->{header}{Location} = $location;
	$redirect
}

# Конструктор ошибки "ошибка в переданных параметрах"
sub bad_request {
	my ($cls, $desc) = splice @_, 0, 2;
	$cls->new(status => "400 Bad Request", desc => $desc // "Некорректные параметры запроса.", is_error=>1, @_)
}

# Конструктор ошибки "требуется авторизация"
sub unauthorized {
	my ($cls, $desc) = splice @_, 0, 2;
	$cls->new(status => "401 Unauthorized", desc => $desc // "Веб-сёрфингист не представился.", is_error => 1, @_)
}

# Конструктор ошибки "запрещено данному пользователю"
sub forbidden {
	my ($cls, $desc) = splice @_, 0, 2;
	$cls->new(status => "403 Forbidden", desc => $desc // "Запрещено данному пользователю.", is_error => 1, @_)
}

# Конструктор ошибки "ошибка в переданных параметрах"
sub method_not_allowed {
	my ($cls, $desc) = splice @_, 0, 2;
	$cls->new(status => "403 Method Not Allowed", desc => $desc // "Неизвестный метод.", is_error=>1, @_)
}

# Конструктор ошибки "нет такой страницы на сайте"
sub not_found {
	my ($cls, $desc) = splice @_, 0, 2;
	$cls->new(status => "404 Not Found", desc => $desc // "Страница не найдена.", is_error => 1, @_)
}

# Закончилось время на запрос
sub request_timeout {
	my ($cls, $desc) = splice @_, 0, 2;
	$cls->new(status => "408 Request Timeout", desc => $desc // "Запрос завершон по таймауту.", is_error => 2, @_)
}

# Конструктор ошибки "пятисотит"
sub internal_server_error {
	my ($cls, $desc) = splice @_, 0, 2;
	$cls->new(status => "500 Internal Server Error", desc => $desc // "Ошибка сервера.", is_error => 1, @_)
}

1;