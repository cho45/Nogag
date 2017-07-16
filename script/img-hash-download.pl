#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';

use Nogag;
use Nogag::Model::Entry;
use UNIVERSAL::require;
use Encode;
use Log::Minimal;
use LWP::UserAgent;
use Term::ProgressBar;

my $r = Nogag->new({});
my $imgcache = $r->service('Nogag::Service::SimilarImage');

$imgcache->process_all_photo_entries(sub {
	my ($entry) = @_;
	for my $url (@{ $entry->images }) {
		$imgcache->download($url, progress => 1);
	}
});

__END__
my $imgcache = dir("imgcache");
my $ua = LWP::UserAgent->new;

sub download {
	my ($url) = @_;
	if ($img =~ /google/) {
		# XXX reduce size
		$img =~ s{/s2048/}{/s500/};
	}
	my $hash = sha1_hex($url);

	my $path = $imgcache->file(substr($hash, 0, 2), substr($hash, 2, 2), $hash);
	if (-e $path) {
		infof("already downloaded %s <- %s", $path, $url);
		return $path;
	} else {
		infof("downloading... %s <- %s", $path, $url);
		$path->parent->mkpath;
		my $fh = $path->openw;
		my $term;
		my $res = $ua->request( HTTP::Request->new( GET => $url ), sub {
			my ($data, $res, $proto) = @_;
			unless ($term) {
				$term = Term::ProgressBar->new( $res->header('Content-Length') );
			}
			$term->update( $term->last_update + length $data );
			print $fh $data;
		});
		close $fh;
		unless ($res->is_success) {
			$path->remove;
		}
		return $path;
	}
}


my $r = Nogag->new({});

my $rows =
	$r->dbh->select(q{
		SELECT * FROM entries
		WHERE title LIKE :query
	}, {
		query => '%[photo]%'
	});


for my $row (@$rows) {
	infof("Processing %s", $row->{path});
	my $html = $row->{formatted_body};
	my $imgs = [ map { m{src=['"]?([^'"> ]+)['"]?} } $html =~ m{(<img[^>]+>)} ];
	for my $img (@$imgs) {
		my $to = $row->{id};
		download($img);
	}
}
