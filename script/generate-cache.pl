#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';

use Nogag;
use lib config->root->subdir('lib')->absolute.q();
use HTTP::Message::PSGI;
use HTTP::Request::Common;
use Log::Minimal;
use Time::HiRes qw(gettimeofday tv_interval);

use Nogag::Service::Cache;
use XML::LibXML;
use URI;

$ENV{LANG} = 'C';

my $r = Nogag->new({});

sub create_cache {
	my ($path) = @_;
	my $res = $r->service('Nogag::Service::Cache')->generate_cache_for_path($path);
	if ($res->status ne '200') {
		die $res;
	}
	$res;
}

my $target = shift @ARGV || ':all';

if ($target eq ':all') {
	my $res = Nogag->new(GET('/sitemap.xml', 'Cache-Control' => 'no-cache')->to_psgi)->run->res;
	my $doc = XML::LibXML->load_xml( string => $res->body ); 
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs('s', 'http://www.sitemaps.org/schemas/sitemap/0.9');  
	my $urls = [
		map {
			$xpc->findvalue('.', $_);
		}
		@{ $xpc->findnodes('/s:urlset/s:url/s:loc') }
	];

	my $total = @$urls;
	my $n = 0;
	for my $url (@$urls) {  
		$n++;
		my $path = URI->new($url)->path;
		next if $path =~ qr{^/\d\d\d\d/\d\d/(\d\d/)?};

		my $t0 = [ gettimeofday ];
		create_cache($path);
		my $elapsed = tv_interval($t0);
		infof("[% 5d/%d % 3d%%] process %s %f", $n, $total, $n / $total * 100, $path, $elapsed);
	}
} else {
	$r->service('Nogag::Service::Cache')->__cache->_dbh->do('DELETE FROM cache WHERE cache_key LIKE "%/.page/%"');
	my $rows =
		$r->dbh->select(q{
			SELECT * FROM entries
			WHERE path LIKE :target
			ORDER BY `date` DESC, `path` ASC
		}, {
			target => "$target%"
		});

	for my $row (@$rows) {
		Nogag::Model::Entry->bless($row);
		create_cache($row->path('/'));
	}
}


