#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use File::Zglob;
use Path::Class;
use DateTime::Format::W3CDTF;
use Encode;
use XML::LibXML;

use Nogag;
use Nogag::Time;
use Nogag::Formatter::Markdown;

my $dir = dir(shift @ARGV || "diary-2004-2009");

my $r = Nogag->new({});
$r->dbh->begin_work;

for my $file (sort { $a cmp $b } zglob "$dir/*.xml") {
	next if $file =~ /wb/;
	my $doc = XML::LibXML->load_xml( location => $file );
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs('d', 'http://lowreal.net/d/');

	my $days = $xpc->findnodes('/d:diary/d:day');
	for my $day (@$days) {
		my $date = Nogag::Time->strptime($xpc->findvalue('@date', $day), '%Y-%m-%d');
		my $sections = $xpc->findnodes('d:section', $day);
		for my $section (@$sections) {
			my $datetime = $xpc->findvalue('@datetime', $section) || $xpc->findvalue('@dateime', $section);;
			my $time  = Nogag::Time->gmtime(DateTime::Format::W3CDTF->parse_datetime($datetime)->epoch);
			my $title = $xpc->findvalue('d:title', $section);
			my $body  = $xpc->findnodes('d:body', $section)->[0]->toString;
			my $cats  = [ map { $xpc->findvalue('.', $_) } @{ $xpc->findnodes('d:cat', $section) } ];

			$body =~ s{^\s*<body>|</body>\s*$}{}g;
			$body =~ s{^\s+}{}gm;

			if (@$cats) {
				$title = '[' . join('][', @$cats) . '] ' . $title;
			}

			my $count = $r->dbh->select('SELECT count(*) FROM entries WHERE `date` = ?', { date => $date->strftime('%Y-%m-%d') })->[0]->{'count(*)'} + 1;
			my $path = $date->strftime("%Y/%m/%d") . "/" . $count;
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
						"HTML",
						:date,
						:created_at,
						:modified_at
					)
			}, {
				title          => $title,
				body           => $body,
				formatted_body => $body,
				path           => $path,
				date           => $date->strftime('%Y-%m-%d'),
				created_at     => $time,
				modified_at    => $time,
			});
		}
	}
}

$r->dbh->commit;
