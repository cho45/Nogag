package Nogag::Service;

use utf8;
use strict;
use warnings;
use Scalar::Util qw(weaken);

sub new {
	my ($class, $r) = @_;
	my $self = bless {
		r => $r
	}, $class;
	weaken($self->{r});
	$self;
}

sub dbh { $_[0]->{r}->dbh }




1;
__END__
