#!/usr/bin/env perl
$ENV{PLACK_ENV} = 'development';
use v5.14;
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use Path::Class;
use XML::LibXML;
use Text::Xatena;

use Nogag;
use Nogag::Time;

my $xml = file(shift @ARGV || "../cho45.xml");

my $thx = Text::Xatena->new;

my $r = Nogag->new({});
$r->dbh->begin_work;

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


	for my $section (@$sections) {
		warn $section->{body};

		my $time = Nogag::Time->new($section->{epoch});
		my $sort_time = Nogag::Time->strptime($section->{date}, '%Y-%m-%d') - $section->{number};
		my $path = $sort_time->strftime("%Y/%m/%d") . "/" . $section->{number};

		$r->dbh->update(q{
			INSERT INTO entries
				(
					`title`,
					`body`,
					`formatted_body`,
					`path`,
					`format`,
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
					"hatena",
					:sort_time,
					:created_at,
					:modified_at
				)
		}, {
			title          => $section->{title} || '■',
			body           => $section->{body},
			formatted_body => $thx->format($section->{body}),
			path           => $path,
			sort_time      => $sort_time,
			created_at     => $time,
			modified_at    => $time,
		});

	}

}

$r->dbh->commit;

