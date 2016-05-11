package Nogag::Time;

use utf8;
use strict;
use warnings;
use parent qw(Time::Piece);

use overload '""' => \&cdate,
             'cmp' => \&str_compare,
             'fallback' => undef;

sub cdate {
	my ($self) = @_;
	$self->strftime('%Y-%m-%d %H:%M:%S');
}

sub iso8601 {
	my ($self) = @_;
	my $offset = $self->tzoffset;
	if ($offset == 0) {
		$self->strftime('%Y-%m-%dT%H:%M:%SZ');
	} else {
		my $datetime = $self->strftime('%Y-%m-%dT%H:%M:%S');
		my $min = abs($offset / 60);
		my $hh = $min / 60;
		my $mm = $min % 60;
		sprintf('%s%s%02d:%02d', $datetime, $offset >= 0 ? '+' : '-', $hh, $mm);
	}
}

sub from_db {
	my ($class, $db) = @_;
	$class->strptime($db, '%Y-%m-%d %H:%M:%S') || $class->strptime($db, '%Y-%m-%d');
}

sub from_uri {
	my ($class, $uri) = @_;
	$class->strptime($uri, '%Y%m%d%H%M%S') || $class->strptime($uri, '%Y%m%d');
}

sub for_uri {
	my ($self) = @_;
	$self->strftime('%Y%m%d%H%M%S');
}

sub offset {
	my ($self, $offset) = @_;
	$self + (60 * 60 * $offset)
}

*str_compare = \&Time::Piece::str_compare;

1;
__END__
