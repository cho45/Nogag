package Nogag::Response;

use utf8;
use strict;
use warnings;
use parent qw(Plack::Response);

sub streaming {
	my ($self, $cb) = @_;
	$self->{streaming} = $cb;
}


sub finalize {
	my ($self) = @_;
	if ($self->{streaming}) {
		$self->{streaming};
	} else {
		$self->SUPER::finalize;
	}
}


1;
__END__
