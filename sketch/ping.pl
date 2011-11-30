#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';
use LWP::Simple qw($ua);
use HTTP::Request::Common;

my $base = 'http://lowreal.net';

{
	my $uri = URI->new('http://www.google.com/webmasters/sitemaps/ping');
	$uri->query_form(sitemap => "$base/sitemap.xml");
	my $res = $ua->get($uri);
	unless ($res->is_success) {
		use Data::Dumper;
		warn Dumper $res ;
	}
}

{
	my $uri = URI->new('http://blogsearch.google.co.jp/ping');
	$uri->query_form(
		name       => "",
		url        => "$base/",
		changesURL => "$base/feed",
	);
	my $res = $ua->get($uri);
	unless ($res->is_success) {
		use Data::Dumper;
		warn Dumper $res ;
	}
}

my $res = $ua->request(POST "http://rpc.reader.livedoor.com/ping", 'Content-Type' => 'text/xml', Content => <<EOS);
<?xml version="1.0"?>
<methodCall>
  <methodName>weblogUpdates.ping</methodName>
  <params>
    <param>
      <value></value>
    </param>
    <param>
      <value>$base/feed</value>
    </param>
  </params>
</methodCall>
EOS
unless ($res->content =~ /Thank/) {
	use Data::Dumper;
	warn $res->content =~ m{(<string>.+</string>)};
}

