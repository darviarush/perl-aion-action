package Aion::Action::Util;

use common::sense;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = our @EXPORT_OK = qw/msg trace/;

require DDP;
require Carp;

# сообщение для отладки
my $WAS_MSG = 0;
sub msg(@) {
	$WAS_MSG = 1, print "Content-Type: text/plain; charset=utf-8\n\n" if !$WAS_MSG;
	print "=========================================================\n";
	print DDP::np($_, colored=>0), "\n" for @_;
	print "=========================================================\n";
	$_[0]
}

sub trace(@) { print STDERR "\n---\n", Carp::longmess($_[0] // "?"), "\n---\n" }

1;