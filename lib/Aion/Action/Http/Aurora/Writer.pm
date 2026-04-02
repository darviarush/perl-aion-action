package Aion::Action::Http::Aurora::Writer;

sub write { $_[0]->{write}->($_[1]) }

sub close { $_[0]->{close}->() }

1;
