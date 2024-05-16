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
use URI;
use URI::QueryParam;
use JSON::XS;
use URI;
use Nogag;
use Log::Minimal;
use HTTP::Request::Common;
use List::Util qw(uniq);
use LWP::Simple qw($ua);
binmode STDOUT, 'encoding(utf-8)';

my $r = Nogag->new({});
my $service = $r->service('Nogag::Service::GooglePhotos');
my $root = dir("./static/images/entry");

infof("LOADING google photos target media ids");
my $download_media_items = [];
{
	my $out_file = file("./google-photos-target-media-ids.txt");
	$download_media_items = decode_json($out_file->slurp);
}

my $filename_by_media_id = {};
for my $items (@$download_media_items) {
	my $filename = NFC($items->[0]->{filename});
	if (@$items > 1) {
		for my $item (@$items) {
#			my $dest = $root->file($filename);
#			unlink($dest);
			$filename_by_media_id->{$item->{id}} = sprintf("_%s-%s", $filename, $item->{mediaMetadata}->{creationTime});
		}
	} else {
		$filename_by_media_id->{$items->[0]->{id}} = $filename;
	}
}


my $media_ids = [ grep { 
	my $filename = $filename_by_media_id->{$_};
	my $dest = $root->file($filename);
	!(-f $dest)
} uniq keys %$filename_by_media_id ];

infof("LOADED target medis ids %d", scalar @$media_ids);

while (@$media_ids) {
	my $part = [ splice @$media_ids, 0, 50 ];
	infof("GET %d count media", scalar @$part);
	my $uri = URI->new("https://photoslibrary.googleapis.com/v1/mediaItems:batchGet");
	$uri->query_param(
		mediaItemIds => @$part
	);
	infof("GET %s", $uri);
	my $results = decode_json $service->client->_request(GET "$uri");
	for my $result (@{ $results->{mediaItemResults} }) {
		my $filename = $filename_by_media_id->{$result->{mediaItem}->{id}};
		my $base_url = $result->{mediaItem}->{baseUrl};
		my $download_url = "$base_url=d";

		my $dest = $root->file($filename);
		unless (-f $dest) {
			infof("SAVING %s => %s", $download_url, $dest);
			my $req = GET $download_url;
			my $res = $ua->request($req, "$dest");
			use Data::Dumper;
			warn Dumper $res->code, $res->message, $res->headers;
		}
	}
}

