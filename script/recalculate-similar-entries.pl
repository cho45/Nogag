#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';
use Encode;
use Path::Class;
binmode STDOUT, 'encoding(utf-8)';

use DBI;
use Log::Minimal;

use Nogag;
Nogag->setup_schema;
use Nogag::Service::SimilarEntry;
my $r = Nogag->new({});
my $index = $r->service('Nogag::Service::SimilarEntry');

my $mode = shift || 'similar';

if ($mode eq 'all') {
	$index->reimport_all_entries_and_recalculate;
} elsif ($mode eq 'tfidf') {
	$index->recalculate_tfidf_for_all_entries;
	$index->recalculate_similar_entry_for_all_entries;
} else {
	$index->recalculate_similar_entry_for_all_entries;
}

