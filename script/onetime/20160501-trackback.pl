#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';

use Nogag;
use lib config->root->subdir('lib')->absolute.q();
use HTTP::Message::PSGI;
use HTTP::Request::Common;
use Log::Minimal;
use Time::HiRes qw(gettimeofday tv_interval);

$ENV{LANG} = 'C';

use Nogag::Service::Trackback;

my $r = Nogag->new({});
my $rows =
	$r->dbh->select(q{
		SELECT * FROM entries
		ORDER BY `date` DESC, `path` ASC
	});

for my $row (@$rows) {
	Nogag::Model::Entry->bless($row);
	infof('update_trackbacks(%s)', $row->path);
	$r->service('Nogag::Service::Trackback')->update_trackbacks($row);
}
