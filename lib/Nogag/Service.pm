package Nogag::Service;

use utf8;
use strict;
use warnings;

sub new {
	my ($class, $r) = @_;
	bless {
		r => $r
	}, $class;
}

sub dbh { $_[0]->{r}->dbh }




1;
__END__
