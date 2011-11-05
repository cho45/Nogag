#!/usr/bin/env perl

use v5.14;
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use Path::Class;
use XML::LibXML;

my $xml = file(shift @ARGV);

my $doc = XML::LibXML->load_xml( string => scalar $xml->slurp );
for my $day (@{ $doc->findnodes('diary/day') }) {
	my $date = $day->findvalue('@date');
	my $body = $day->findvalue('body');

	my $sections = [];
	my $number   = 1;

	$body =~ s{^\s+|\s+$}{}g;
	for my $line (split /^/m, $body) {
		if ($line =~ /^\*(?<epoch>\d+)\*(?<title>.*)/) {
			push @$sections, +{
				%+,
				date   => $date,
				number => $number++,
				body   => '',
			};
		} else {
			if (@$sections) {
				$sections->[-1]->{body} .= $line;
			} else {
				push @$sections, +{
					date   => $date,
					number => 0,
					body   => $line,
				};
			}
		}
	}

	use Data::Dumper;
	warn Dumper $sections ;
}

