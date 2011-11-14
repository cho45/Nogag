#!/usr/bin/env perl
$ENV{PLACK_ENV} = 'development';
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use Nogag;
use UNIVERSAL::require;

my $r = Nogag->new({});
$r->dbh->begin_work;

my $rows = $r->dbh->select('SELECT * FROM entries');
for my $row (@$rows) {
	warn $row->{id};

	my $formatter = "Nogag::Formatter::" . $row->{format};
	$formatter->use;

	my $formatted_body = $formatter->format($row->{body});

	$r->dbh->update(q{
		UPDATE entries
		SET
			formatted_body = :formatted_body
		WHERE
			id = :id
	}, {
		formatted_body => $formatted_body,
		id => $row->{id},
	})
}

$r->dbh->commit;
