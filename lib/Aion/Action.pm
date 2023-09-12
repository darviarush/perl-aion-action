package Aion::Action;
# Выполняет экшн в CGI или консоли
use common::sense;

our $VERSION = "0.0.0-prealpha";

# конструктор
sub doit {
	my ($cls) = @_;

	local $|=1;

	eval {
		# Подключаем основную библиотеку
		require query;

		if($main_config::dev and exists $ENV{REMOTE_ADDR} and $ENV{REMOTE_ADDR} !~ /^(127.0.0.1|::1)/) {
			print "Content-Type: text/html; charset=utf-8\n";
			print "Status: 203\n\n";
			print "DEV $ENV{REMOTE_ADDR}";
			return "REMOTE_ADDR";
		}

		# Вешаем таймаут на запрос
		require POSIX;
		require Time::HiRes;
		POSIX::sigaction(POSIX::SIGALRM(), POSIX::SigAction->new(sub {
			my $t = Time::HiRes::time();
			# завершаем sql-запрос
			eval { query::query_stop() };

			eval {
				my $stop_query = Time::HiRes::time() - $t;
				
				require Aion::Response;
				Aion::Response->request_timeout("Превышено время ожидания",
					stop_query => $stop_query,
					timeout => $main_config::action_timeout,
				)->print;
				
				#_send_error_to_canal(408, "Превышено время ожидания. Таймаут: $main_config::action_timeout. Прервана сессия mariadb за $stop_query сек.");
			};
			if($@) {
				# выдаём ошибку
				print "Status: 408 Request Timeout\n";
				print "Content-Type: text/plain; charset=utf8\n\n";
				print "= 408 Request Timeout\n\n";
				print "Запрос завершён по таймауту!\n";
				print "$@" if $main_config::dev;
			}
			exit;
		}));
		alarm $main_config::action_timeout;

		# подключаем класс с ответом
		require Aion::Response;

		# инициализируем объект запроса
		require Aion::Request;
		$query::q = my $q = Aion::Request->new->init;

		if($main_config::dev) {
			require Aion::Navigator if $main_config::navigator;
			require Eon::Html::Ed;
		}

		require Aion::Routing;

		my $method = uc $q->method;
		die Aion::Response->method_not_allowed("Метод $method не поддерживается") if $method !~ /^($main_config::METHODS)$/;
		
		(my $route, $q->{SLUG}) = Aion::Routing->new->route($q->path);

		die Aion::Response->not_found("Нет соответствующего роута") if !defined $route;
		die Aion::Response->method_not_allowed("Метод $method не используется в роуте " . query::to_json($route)) if !exists $route->{$method};

		my ($class, $action) = split /#/, $route->{$method}{action};

		eval "require $class";
		die if $@;

		my $page = $class->create_from_request($q)->$action($q);

		if(ref $page eq "Aion::Response") {
			$page->print;
		}
		elsif(ref $page eq "HASH") {
			#query::debug_array($page) if $main_config::dev;
			Aion::Response->new(type => "text/plain", content=>$page)->print;
		}
		else {
			if($main_config::dev) {
				
				if($main_config::navigator) {
					my $nav = Aion::Navigator->new->render;
					$page =~ s/\z/$nav/;
				}
				
				#$page =~ s/\z/\n<!--\n${\query::debug_text()}\n-->\n/ if @query::DEBUG;
			}
	    	Aion::Response->new(type => "text/html", content=>$page)->print;
	    }
	};
	if(my $err = $@) {

		eval { $err->print } and return if UNIVERSAL::isa($err, "Aion::Response");

		eval {
			_send_error_to_canal(500, $err);
			Aion::Response->internal_server_error->print;
		} and return if !$main_config::dev;

		my $err2 = $@;

		print "Status: 500 Internal Server Error\n";
	    print "Content-Type: text/plain; charset=utf8\n\n";
	    print "Оригинальное сообщение:\n";
	    print "=======================\n";
		(ref $err? eval { query::msg($err) }: 0) || print $err, "\n";
		if($err ne $err2) {
			print "-------------------------\n";
			print "Дополнительное сообщение:\n";
			print "=========================\n";
			(ref $err2? eval { query::msg($err2) }: 0) || print $err2, "\n";
		}

	    print query::debug_text() if *query::debug_text{CODE};
	}
	return;
}

# Отправляем ошибку 
sub _send_error_to_canal {
	my ($code, $err) = @_;
	require query;
	my $POST = $query::q->POST;
	query::tech_message(join "", 
		query::to_html($query::q->method), " ", query::to_html("https://" . $query::q->host . $query::q->uri),
		"\n\n<i>", query::to_html($query::q->agent), "</i>",
		keys %$POST? ("\n\nС данными: <code>", query::to_html(query::np($POST)), "</code>"): (),
		"\n\n<b>$code-ка:</b>\n<code>", query::to_html($err), "</code>",
		"\n\n<i>SQL:</i>\n<code>", query::to_html(query::debug_text()), "</code>",
	);
}

1;
