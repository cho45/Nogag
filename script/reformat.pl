#!/usr/bin/env perl
use utf8;
use strict;
use warnings FATAL => qw(all);
use lib lib => glob 'modules/*/lib';

use Nogag;
use Nogag::Model::Entry;
use UNIVERSAL::require;
use Encode;

my $r = Nogag->new({});
$r->dbh->begin_work;

my $target = shift @ARGV or die;

my $rows = $target eq ':all' ?
	$r->dbh->select(q{
		SELECT * FROM entries
		ORDER BY `date` DESC, `path` ASC
	}):
	$r->dbh->select(q{
		SELECT * FROM entries
		WHERE path LIKE :target
	}, {
		target => "$target%"
	});


printf "%d rows, ok?", scalar @$rows;
<>;

for my $row (@$rows) {
	Nogag::Model::Entry->bless($row);

	my $formatter = "Nogag::Formatter::" . $row->format;
	$formatter->use;

	printf "id:%d, path:%s = %s\n", $row->id, $row->path, $formatter;

	my $formatted_body = $formatter->format($row);

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
