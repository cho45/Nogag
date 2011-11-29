#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use File::Zglob;
use Path::Class;
use DateTime::Format::W3CDTF;
use Encode;

use Nogag;
use Nogag::Time;
use Nogag::Formatter::Markdown;
use Nogag::Model::Entry;

my $dir = dir(shift @ARGV || "diary-2006-2009");

sub parse_file ($) {
	my ($file) = @_;
	my ($title, @body) = file($file)->slurp;
	my $meta = {};
	while ($body[0] =~ m{^meta-(?<name>[^:\s]+):\s*(?<value>.+)}) {
		shift @body;
		$meta->{$+{name}} = $+{value};
	}

	($title, $meta, join('', @body));
}


my $files = [
	sort {
		$a->{meta}->{creation_date} cmp $b->{meta}->{creation_date}
	}
	map {
		my ($title, $meta, $body) = parse_file($_);
		+{
			meta       => $meta,
			title      => $title,
			body       => $body,
			file       => $_,
		}
	}
	zglob("$dir/**/*.txt")
];

my $r = Nogag->new({});
$r->dbh->begin_work;

for my $file (@$files) {
	my $time = Nogag::Time->gmtime(DateTime::Format::W3CDTF->parse_datetime($file->{meta}->{creation_date})->epoch);
	my $date = Nogag::Time->localtime($time->epoch);

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
				"Markdown",
				:date,
				:created_at,
				:modified_at
			)
	}, {
		title          => decode_utf8($file->{title} || ''),
		body           => decode_utf8($file->{body}),
		formatted_body => Nogag::Formatter::Markdown->format(Nogag::Model::Entry->bless({ path => $path, body => decode_utf8($file->{body}) })),
		path           => $path,
		date           => $date->strftime('%Y-%m-%d'),
		created_at     => $time,
		modified_at    => $time,
	}),
}

$r->dbh->commit;
