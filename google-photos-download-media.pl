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

infof("LOADING google photos target media ids");
my $media_ids = [];
{
	my $out_file = file("./google-photos-target-media-ids.txt");
	$media_ids = decode_json($out_file->slurp);
}

$media_ids = [ uniq @$media_ids ];

infof("LOADED target medis ids %d", scalar @$media_ids);

my $service = $r->service('Nogag::Service::GooglePhotos');
my $root = dir("./static/images/entry");

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
		my $filename = NFC($result->{mediaItem}->{filename});
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

