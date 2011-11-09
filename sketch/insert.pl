#!/usr/bin/env perl
$ENV{PLACK_ENV} = 'development';
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use Nogag;

my $r = Nogag->new({});

$r->dbh->begin_work;

for my $i (1..100) {
	my $now = gmtime;
	$r->dbh->update(q{
		INSERT INTO entries
			(
				`title`,
				`body`,
				`formatted_body`,
				`path`,
				`sort_time`,
				`created_at`,
				`modified_at`
			)
			VALUES
			(
				:title,
				:body,
				:formatted_body,
				:path,
				:sort_time,
				:created_at,
				:modified_at
			)
	}, {
		title          => "test$i",
		body           => "foobar$i",
		formatted_body => "foobar$i",
		path           => '2011/01/01',
		sort_time      => $now,
		created_at     => $now,
		modified_at    => $now,
	});
}

$r->dbh->commit;
