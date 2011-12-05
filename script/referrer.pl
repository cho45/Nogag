#!/usr/bin/env perl

use v5.14;
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use File::Zglob;

my $logs = [
	map {
		$_->[0]
	}
	sort {
		$a->[1] <=> $b->[1];
	}
	map {
		/\.(\d+)(?:\.gz)?$/;
		[ $_, $1 || 0 ];
	}
	zglob '/var/log/nginx/lowreal.net.access.log*'
];

for my $log (@$logs) {
	my $is_gz = ($log =~ /\.gz$/);
	open my $fh, $is_gz ? "zcat $log |" : "< $log";
	while (<$fh>) {
		chomp;
		my %data = map { split /\s*:\s*/, $_, 2 } split /\t/;
		next if !$data{referer};
		next if $data{referer} eq '-';
		next if $data{referer} =~ m{^http://lowreal\.net};
		next if $data{referer} =~ m{^http://www\.lowreal\.net};
		next if $data{referer} =~ m{^http://\Qsubtech.g.hatena.ne.jp\E};
		say "$data{time} $data{referer}";
	}
	close $fh;
}

