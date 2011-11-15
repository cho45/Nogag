#!/usr/bin/env perl
$ENV{PLACK_ENV} = 'development';
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use Nogag;
use Nogag::Time;

my $r = Nogag->new({});

my $dates = $r->dbh->select(q{
	SELECT
		strftime('%Y', sort_time) as year,
		strftime('%Y-%m', sort_time) as date,
		count(*) as count
	FROM entries
	GROUP BY strftime('%Y-%m', sort_time)
	ORDER BY sort_time
});

my %dates = map { $_->{date} => $_->{count} } @$dates;

my $years = [];
for my $year ($dates->[0]->{year} .. $dates->[-1]->{year}) {
	my $months = [];
	for my $month (1..12) {
		push @$months, +{
			month => $month,
			count => $dates{sprintf("%04d-%02d", $year, $month)} || 0,
		};
	}
	push @$years, $months;
}

use Data::Dumper;
warn Dumper $years ;
