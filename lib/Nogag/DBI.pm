package Nogag::DBI;

use utf8;
use strict;
use warnings;
use parent qw(DBI);


package
	DBI::db;

use SQL::NamedPlaceholder qw(bind_named);
use Nogag::Config;
use Data::Dumper;

sub select {
	my ($self, $sql, $bind) = @_;
	($sql, $bind) = bind_named($sql, $bind || {});
	if (config->param('explain')) {
		my $s = $sql;
		$s =~ s{\s+}{ }g;
		$s =~ s{^\s+|\s+$}{}g;
		warn Dumper [
			[$s, @$bind ? $bind : ()],
			join(':', (caller(0))[1], (caller(0))[2]),
			map {
				$_->{detail}
			}
			@{ $self->selectall_arrayref('EXPLAIN QUERY PLAN ' . $sql, { Slice => {} }, @$bind) }
		];
	}
	$self->selectall_arrayref($sql, { Slice => {} }, @$bind);
}

sub value {
	my ($self, $sql, $bind) = @_;
	my $first = $self->select($sql, $bind)->[0];
	(values %$first)[0];
}

sub update {
	my ($self, $sql, $bind) = @_;
	($sql, $bind) = bind_named($sql, $bind || {});
	$self->prepare_cached($sql)->execute(@$bind);
}


1;
__END__
