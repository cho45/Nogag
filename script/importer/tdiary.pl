#!/usr/bin/env perl
use v5.14;
use utf8;
use lib lib => glob 'modules/*/lib';

use File::Zglob;
use Path::Class;
use DateTime::Format::W3CDTF;
use Encode;
use XML::LibXML;

use Nogag;
use Nogag::Time;
use Nogag::Formatter::Markdown;
use Nogag::Model::Entry;

my $dir = dir(shift @ARGV || "diary-2003-2004");

my $r = Nogag->new({});
$r->dbh->begin_work;

sub insert {
	my $hash = shift;

	my $formatter = "Nogag::Formatter::" . $hash->{format};
	$formatter->use;

	my $count = $r->dbh->select('SELECT count(*) FROM entries WHERE `date` = ?', { date => $hash->{date}->strftime('%Y-%m-%d') })->[0]->{'count(*)'} + 1;
	my $path  = $hash->{date}->strftime("%Y/%m/%d") . "/" . $count;

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
		formatted_body => $formatter->format(Nogag::Model::Entry->bless({ path => $path, body => $hash->{body} })),
		path           => $path,
		format         => $hash->{format},
		date           => $hash->{date}->strftime('%Y-%m-%d'),
		created_at     => $hash->{time},
		modified_at    => $hash->{time},
	});
}

for my $file (sort { $a cmp $b } zglob "$dir/**/*.td2") {
	my $tdiary = decode('euc-jp', file($file)->slurp);

	$tdiary =~ s{^TDIARY2\.00\.00\n}{};

	for my $day (split /\n\.\n/, $tdiary) {
		next if $day =~ /^\s*$/;
		my ($header, @sections) = split /\n\n/, $day;

		$header = +{
			map { s/^\s*|\s*$//rg }
			map { split /:/ }
			split /\n/, $header
		};

		my $date = Nogag::Time->strptime($header->{Date}, '%Y%m%d');

		given ($header->{Format}) {
			when ('tDiary') {
				for my $section (@sections) {
					my ($title, @body) = split /\n/, $section;
					my $body = join("\n", @body);
					insert({
						title  => $title,
						body   => $body,
						date   => $date,
						time   => $date->offset(-9),
						format => 'tDiary',
					});
				}
			}

			when ('Hatena') {
				for my $section (@sections) {
					my ($title, @body) = split /\n/, $section;
					$title =~ s{^\*(?:(\d+)\*)}{}e;
					my $time = Nogag::Time->gmtime($1);

					my $body = join("\n", @body);
					insert({
						title  => $title,
						body   => $body,
						date   => $date,
						time   => $time,
						format => 'Hatena',
					});
				}
			}

			default {
				die "Unknown format:" . $header->{Format};
			}
		}

	}

}

$r->dbh->commit;
