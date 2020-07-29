#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use v5.14.0;
use lib lib => glob 'modules/*/lib';
use Encode;
use Unicode::Normalize;
use Path::Class;
use URI::Escape;
use JSON::XS;
use URI;
use Nogag;
use Log::Minimal;
binmode STDOUT, 'encoding(utf-8)';

my $r = Nogag->new({});

my $map = {};

infof("LOADING google photos metadata file");
{
	my $out_file = file("out.txt");
	my $out = $out_file->open or die "cant open file $!";
	while (my $line = <$out>) {
		my $item = decode_json($line);
		my $fn = NFC($item->{filename});
		$map->{$fn} = $item->{id};
	}
	$out->close;
}

sub map_of {
	my ($filename) = @_;
	$map->{$filename} and return $map->{$filename};
	$filename =~ s{ }{20}g;
	$map->{$filename} and return $map->{$filename};
	return undef;
}

infof("SEARCHING TARGET <img> elements");
my $rows =
	$r->dbh->select(q{
		SELECT * FROM entries
		WHERE body LIKE :query
		ORDER BY id DESC
	}, {
		query => '%<img%'
	});

say scalar @$rows;

my $media_ids = [];

sub replace {
	my ($img) = @_;
	my ($a, $b) = ($img =~ /src=(?:"([^"]+)"|'([^']+)')/);
	my $uri = $a || $b;
	my ($filename) = ($uri =~ m{([^/]+)$});
	$filename = uri_unescape(uri_unescape($filename));
	$filename =~ s/\+/ /g;
	$filename = NFC(decode_utf8($filename));

	my $media_id = map_of($filename);
	if ($media_id) {
		my $new = $img;
		my $path = sprintf("/images/entry/$filename", uri_escape_utf8($filename));
		$new =~ s{src=(?:"([^"]+)"|'([^']+)')}{src="$path"};
		infof("REPLACE %s => %s", $img, $new);
		push @$media_ids, $media_id;
		$new;
	} else {
		$img;
	}
};

for my $entry (@$rows) {
	Nogag::Model::Entry->bless($entry);

	my $body = $entry->body;
	$body =~ s{<img[^>]+>}{replace($&)}ge;

	if ($body ne $entry->body) {
		infof("UPDATE entry https://lowreal.net/%s", $entry->path);
		$entry = $r->service('Nogag::Service::Entry')->update_entry($entry,
			title      => $entry->raw_title,
			body       => $body,
		);
	}
}

{
	my $out = file("google-photos-target-media-ids.txt");
	my $fh = $out->open("w") or die $!;
	$fh->print(encode_json($media_ids));
	$fh->close;
}

