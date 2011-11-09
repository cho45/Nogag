package Nogag::DBI;

use utf8;
use strict;
use warnings;
use parent qw(DBI);


package
	DBI::db;

use SQL::NamedPlaceholder qw(bind_named);

sub select {
	my ($self, $sql, $bind) = @_;
	($sql, $bind) = bind_named($sql, $bind);
	my $sth = $self->prepare_cached($sql);
	$sth->bind_columns(@$bind);
	$sth->fetchall_arrayref({ Slice => {} });
}


sub update {
	my ($self, $sql, $bind) = @_;
	($sql, $bind) = bind_named($sql, $bind);
	$self->prepare_cached($sql)->execute(@$bind);
}


1;
__END__
