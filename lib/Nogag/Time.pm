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

*str_compare = \&Time::Piece::str_compare;

1;
__END__
