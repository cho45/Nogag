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

my $service = $r->service('Nogag::Service::GooglePhotos');

use Data::Dumper;
use HTTP::Request::Common;
use URI;
use URI::QueryParam;
sub request_list {
	my ($pageToken) = @_;
	my $uri = URI->new("https://photoslibrary.googleapis.com/v1/mediaItems");
	$uri->query_form_hash({
		pageSize => 100,
		($pageToken ? (pageToken =>  $pageToken) : ())
	});

	my $wait = 1;

	while (1) {
		infof("GET $uri");
		my $res = $service->client->_raw_request(GET "$uri");
		if ($res->code != 200) {
			# quota
			warnf("GET $uri => %03d %s (retry after %d)", $res->code, $res->message, $wait);
			sleep $wait;
			$wait *= 2;
			next;
		}
		my $data = decode_json($res->decoded_content);
		return $data;
	}
}

my $out_file = file("out.txt");
my $out = $out_file->open("a") or die "cant open file $!";
my $pageToken = undef;
my $count = 0;
while (1) {
	my $list = request_list($pageToken);
	$count++;
	infof("LIST COUNT %d", $count);
	if (!($pageToken = $list->{nextPageToken})) {
		last;
	}
	for my $item (@{ $list->{mediaItems} }) {
		$out->print(encode_json($item), "\n");
	};
}
$out->close;


