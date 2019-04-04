#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';


use LWP::Authen::Wsse;
use XML::Atom;
use Atompub::Client;
use Term::ReadKey;
use Log::Minimal;
use DateTime::Format::ISO8601;
use Time::Seconds;
use Encode;

use Nogag;
use Nogag::Time;
use Nogag::Model::Entry;
use Nogag::Formatter::Hatena;


my $hatena_id = 'cho45';
my $blog_id = 'itisnevertoolatetolearn.hatenadiary.jp';

printf "API Key (get from https://blog.hatena.ne.jp/%s/%s/config/detail ): ", $hatena_id, $blog_id;
ReadMode('noecho');
my $password = ReadLine(0);
chomp $password;


my $client = Atompub::Client->new;
$client->username($hatena_id);
$client->password($password);

infof("Get service document");
my $service = $client->getService(sprintf("https://blog.hatena.ne.jp/%s/%s/atom", $hatena_id, $blog_id)) or do {
	use Data::Dumper;
	warn Dumper $client->res ;
	die;
};

my @workspaces = $service->workspaces;
my @collections = $workspaces[0]->collections;

my $collection_uri = $collections[0]->href;

infof("get feed %s", $collection_uri);
my $feed = $client->getFeed($collection_uri);
my $next = [ map { $_->href } grep { $_->rel eq 'next'  } $feed->link ]->[0];

my $r = Nogag->new({});
$r->dbh->begin_work;

for my $entry ($feed->entries) {
	my $title = decode_utf8 $entry->title;
	my $created_at = Nogag::Time->gmtime(DateTime::Format::ISO8601->parse_datetime($entry->published)->epoch);
	my $modified_at = Nogag::Time->gmtime(DateTime::Format::ISO8601->parse_datetime($entry->updated)->epoch);
	my $format;
	if ($entry->content->type eq 'text/html') {
		$format = "HTML";
	} elsif ($entry->content->type eq 'text/x-hatena-syntax') {
		$format = "Hatena";
	} else {
		die "unsupported format:" . $entry->content->type;
	};
	my $body = $entry->content->body;
	my $entry = Nogag::Model::Entry->bless({
		title => $title,
		body => $body,
		created_at => $created_at.q(),
		modified_at => $modified_at.q(),
		status => "scheduled",
		format => $format,
		publish_at => ($created_at + ONE_DAY * 30).q(),
	});
	$entry->{formatted_body} = $r->service("Nogag::Service::Entry")->format_body($entry);

	my $exists = $r->dbh->select(q{ SELECT * FROM entries WHERE created_at = :created_at }, {
		created_at => $entry->created_at
	})->[0];

	if ($exists) {
		infof("Already exists entry");
		$entry->{path} = $exists->{path};
		$r->dbh->update(q{DELETE FROM entries WHERE created_at = :created_at }, { created_at => $entry->created_at });
	} else {
		my $count = $r->dbh->select('SELECT count(*) FROM entries WHERE `date` = ?', { date => $created_at->strftime('%Y-%m-%d') })->[0]->{'count(*)'} + 1;
		my $path  = $created_at->strftime("%Y/%m/%d") . "/" . $count;
		infof("Create %s", $path);

		$entry->{path} = $path;
	}

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
				`modified_at`,
				`status`,
				`publish_at`
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
				:modified_at,
				:status,
				:publish_at
			)
	}, {
		title          => $entry->{title} || '',
		body           => $entry->{body} || '',
		formatted_body => $entry->{formatted_body},
		path           => $entry->{path},
		date           => $entry->created_at->strftime('%Y-%m-%d'),
		created_at     => $entry->created_at,
		modified_at    => $entry->modified_at,
		publish_at     => $entry->publish_at,
		format         => $format,
		status         => "scheduled",
	});
}


$r->dbh->commit;
