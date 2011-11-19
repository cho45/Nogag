#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use File::Zglob;
use Path::Class;
use Encode;
use HTML::TreeBuilder::XPath;

use Nogag;
use Nogag::Time;
use Nogag::Formatter::Markdown;

my $dir = dir(shift @ARGV || "diary-2002-2003");

my $r = Nogag->new({});
$r->dbh->begin_work;

sub insert {
	my $hash = shift;

	my $formatter = "Nogag::Formatter::" . $hash->{format};
	$formatter->use;

	my $count = $r->dbh->select('SELECT count(*) FROM entries WHERE `date` = ?', { date => $hash->{date} })->[0]->{'count(*)'};
	my $path  = $hash->{date}->strftime("%Y/%m/%d") . "/" . ($count + 1);
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
				:format,
				:date,
				:created_at,
				:modified_at
			)
	}, {
		title          => $hash->{title} || '',
		body           => $hash->{body},
		formatted_body => $formatter->format($hash->{body}),
		path           => $path,
		format         => $hash->{format},
		date           => $hash->{date}->strftime('%Y-%m-%d'),
		created_at     => $hash->{time},
		modified_at    => $hash->{time},
	});
}

for my $file (sort { $a cmp $b } zglob "$dir/*") {
	my $content = decode_utf8 file($file)->slurp;

	if ($content =~ m{<div class="section">}) {
		my $tree = HTML::TreeBuilder::XPath->new_from_content($content);

		my $sections = $tree->findnodes('//div[@class="section" and h2]');
		for my $section (@$sections) {
			my $title = $section->findvalue('h2');
			my $date  = eval { Nogag::Time->strptime($title, '#%Y%m%d %H%M') } or next;

			my $html = $section->as_HTML('<>&', ' ');
			$html =~ s{^\s*<div class="section">[\s\S]+?</h2>}{};
			$html =~ s{</div>\s*$}{};
			$html =~ s{^\s+}{}gm;

			insert({
				title  => '',
				body   => $html,
				date   => $date,
				time   => $date->offset(-9),
				format => 'HTML',
			});
		}

		$tree->delete;
	} else {
		my $sections = [];
		$content =~ s!<h2>(?<datetime>#\d{8} \d{4})</h2>\n<p>(?<body>[\s\S]+?)</p>|<p>\s*<strong>(?<datetime>#\d{8} \d{4})</strong><br />(?<body>[\s\S]+?)</p>!
			push @$sections, { %+ };
		!ge;
		@$sections or die $file;

		for my $section (@$sections) {
			my $date  = Nogag::Time->strptime($section->{datetime}, '#%Y%m%d %H%M');

			insert({
				title  => '',
				body   => '<p>' . $section->{body} . '</p>',
				date   => $date,
				time   => $date->offset(-9),
				format => 'HTML',
			});
		}
	}
}

$r->dbh->commit;
