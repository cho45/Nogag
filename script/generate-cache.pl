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

sub create_cache {
	my ($path) = @_;
	my $t0 = [ gettimeofday ];
	my $res = Nogag->new(GET($path, 'Cache-Control' => 'no-cache')->to_psgi)->run->res;
	if ($res->status ne '200') {
		die $res;
	}
	my $elapsed = tv_interval($t0);
	infof("created for %s with %d", $path, $elapsed * 1000);
	$res;
}

my $target = shift @ARGV || ':all';

if ($target eq ':all' || $target eq ':index') {
	create_cache('/');
}


my $r = Nogag->new({});
my $rows = $target eq ':all' ?
	$r->dbh->select(q{
		SELECT * FROM entries
		ORDER BY `date` DESC, `path` ASC
	}):
	$r->dbh->select(q{
		SELECT * FROM entries
		WHERE path LIKE :target
		ORDER BY `date` DESC, `path` ASC
	}, {
		target => "$target%"
	});

for my $row (@$rows) {
	Nogag::Model::Entry->bless($row);
	create_cache($row->path('/'));
}
