#!/usr/bin/env perl
use utf8;
use strict;
use warnings FATAL => qw(all);
use lib lib => glob 'modules/*/lib';

use Nogag;
use UNIVERSAL::require;
use Encode;

my $r = Nogag->new({});
$r->dbh->begin_work;

my $rows = $r->dbh->select(q{
	SELECT * FROM entries
	ORDER BY `date` DESC, `path` ASC
	LIMIT 500
});
for my $row (@$rows) {
	my $formatter = "Nogag::Formatter::" . $row->{format};
	$formatter->use;

	warn $row->{id};

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
