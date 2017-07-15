#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';

use Image::Libpuzzle;

use Nogag;
use Data::Dumper;
use Log::Minimal;

Nogag->setup_schema;

my $r = Nogag->new({});

my $imgcache = $r->service('Nogag::Service::SimilarImage');
my $force = 0;

$imgcache->process_all_photo_entries(sub {
	my ($entry) = @_;
	if ($force) {
		$imgcache->index($entry);
	} else {
		my $exists = $r->images_dbh->value(q{SELECT COUNT(*) FROM images WHERE entry_id = :entry_id}, { entry_id => $entry->id });
		unless ($exists) {
			$imgcache->index($entry);
		}
	}
});

