#!/usr/bin/env perl
$ENV{PLACK_ENV} = 'development';
use v5.14;
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use Path::Class;
use XML::LibXML;

use Nogag;
use Nogag::Time;
use Nogag::Formatter::Hatena;

my $xml = file(shift @ARGV || "../cho45.xml");
my $user = $xml->basename;
$user =~ s/\.xml$//;

my $r = Nogag->new({});
$r->dbh->begin_work;

my $doc = XML::LibXML->load_xml( string => scalar $xml->slurp );
for my $day (@{ $doc->findnodes('diary/day') }) {
	my $date = $day->findvalue('@date');
	my $body = $day->findvalue('body');

	my $sections = [];
	my $number   = 1;

	$body =~ s{^\s+|\s+$}{}g;
	$body =~ s{http://d.hatena.ne.jp/$user/(\d\d\d\d)(\d\d)(\d\d)#(\d+)}{
		sprintf('/%04d/%02d/%02d/#post-%d', $1, $2, $3, $4);
	}ge;
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
#		use Data::Dumper;
#		warn Dumper $section ;

		my $time = Nogag::Time->gmtime($section->{epoch} + 0);
		my $date = Nogag::Time->strptime($section->{date}, '%Y-%m-%d');

		my $count = $r->dbh->select('SELECT count(*) FROM entries WHERE `date` = ?', { date => $date })->[0]->{'count(*)'};
		my $path  = $date->strftime("%Y/%m/%d") . "/" . ($count + 1);
		warn $path;

		$r->dbh->update(q{
			INSERT INTO entries
				(
					`title`,
					`body`,
					`formatted_body`,
					`path`,
					`format`,
					`date`,
					`created_at`,
					`modified_at`
				)
				VALUES
				(
					:title,
					:body,
					:formatted_body,
					:path,
					"Hatena",
					:date,
					:created_at,
					:modified_at
				)
		}, {
			title          => $section->{title} || '',
			body           => $section->{body},
			formatted_body => Nogag::Formatter::Hatena->format($section->{body}),
			path           => $path,
			date           => $date->strftime('%Y-%m-%d'),
			created_at     => $time,
			modified_at    => $time,
		});

	}

}

$r->dbh->commit;

