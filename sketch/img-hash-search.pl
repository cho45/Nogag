#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';
use Path::Class;
use List::MoreUtils qw(first_value);
use URI;

use Nogag;
use Nogag::Model::Entry;
my $r = Nogag->new({});

my $path = shift;
$path = substr(URI->new($path)->path, 1);

my $entry = $r->dbh->select(q{
	SELECT * FROM entries
	WHERE path = :path
}, {
	path => $path,
})->[0];
Nogag::Model::Entry->bless($entry);

my $imgcache = $r->service('Nogag::Service::SimilarImage');
my $dbh = $r->images_dbh;
for my $url (@{ $entry->images }) {
	warn $url;

	my $res = $imgcache->similar_photos($url, limit => 5);

	for my $row (@$res) {
		printf("% 4d : % 5d : %s\n", $row->{score}, $row->{entry_id}, $row->{uri});
	}

}

__END__
my $list = [
	map {
		chomp;
		my ($hash, $id) = split /,/;
		my $int = $hash + 0; # unpack("q", pack("b*", $hash));
		+{
			hash => $int,
			id => $id,
		}
	} file('./hashed.log')->slurp
];

my $path = shift;
$path = substr(URI->new($path)->path, 1);

my $entry = $r->dbh->select(q{
	SELECT * FROM entries
	WHERE path = :path
}, {
	path => $path,
})->[0];

my $target = first_value {
	$_->{id} == $entry->{id}
} @$list;

$target or die "not found entry";

sub hamming_distance {
	my ($a, $b) = @_;
	my $diff = $a ^ $b;
	my $count = 0;
	for my $b ( 0 .. 63 ) {
		my $mask = 1 << $b;
		++$count if $diff & $mask
	}
	$count
}

use Data::Dumper;
warn Dumper $target;

my $sorted = [
	sort {
		$a->{distance} <=> $b->{distance};
	}
	map {
		+{
			%$_,
			distance => hamming_distance($target->{hash}, $_->{hash}),
		}
	}
	@$list
];

for (1..10) {
	my $x = $sorted->[$_];
	my $entry = $r->dbh->select(q{
		SELECT * FROM entries WHERE id = :id
	}, { id => $x->{id} })->[0];
	print $x->{distance}, " ", "https://lowreal.net/", $entry->{path}, "\n";
}
