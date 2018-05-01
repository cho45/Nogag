use strict;
use warnings;
use lib 't/lib';

use Test::Time;
use Test::More;
use Test::Name::FromLine;
use Nogag::Test;

use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Router::Simple;
use JSON;
use Time::Seconds;

use Nogag;
use Nogag::Time;
use Nogag::Service::Entry;

my $postprocess = postprocess(dummy => 1);

my $r = Nogag->new({});
my $service = Nogag::Service::Entry->new($r);


subtest create_new_entry => sub {
	{
		my $entry = $service->create_new_entry(
			title => 'foo',
			body => 'bar',
		);

		is $entry->title, 'foo';
		is $entry->body, 'bar';
		is $entry->format, 'Hatena';
		is $entry->publish_at, undef;
		is $entry->status, 'public';
		ok $entry->created_at;
		ok $entry->modified_at;
	};

	{
		my $entry = $service->create_new_entry(
			title => 'foo',
			body => 'bar',
			publish_at => scalar gmtime(1524734038),
			status => 'scheduled',
		);

		is $entry->title, 'foo';
		is $entry->body, 'bar';
		is $entry->format, 'Hatena';
		is $entry->publish_at, '2018-04-26 09:13:58';
		is $entry->status, 'scheduled';
		ok $entry->created_at;
		ok $entry->modified_at;
	}

	{
		my $entry = $service->create_new_entry(
			title => 'foo',
			body => 'bar',
			publish_at => scalar localtime() + 10,
			status => 'public',
		);

		is $entry->title, 'foo';
		is $entry->body, 'bar';
		is $entry->format, 'Hatena';
		is $entry->status, 'scheduled', 'ensure status to scheduled with future publish_at';
		ok $entry->created_at;
		ok $entry->modified_at;
	}
};

subtest update_entry => sub {
	{
		my $entry = $service->create_new_entry(
			title => 'foo',
			body => 'bar',
			publish_at => scalar localtime(1524734038),
			status => 'scheduled',
		);

		is $entry->title, 'foo';
		is $entry->body, 'bar';
		is $entry->format, 'Hatena';
		is $entry->publish_at, '2018-04-26 09:13:58';
		is $entry->status, 'scheduled';
		ok $entry->created_at;
		ok $entry->modified_at;

		sleep 1;

		$entry = $service->update_entry($entry,
			title => 'foo1',
			body => 'bar1',
			publish_at => scalar localtime(1524734039),
			status => 'scheduled',
		);

		is $entry->title, 'foo1';
		is $entry->body, 'bar1';
		is $entry->format, 'Hatena';
		is $entry->publish_at, '2018-04-26 09:13:59';
		is $entry->status, 'scheduled';
	}
};

subtest publish_scheduled_entries => sub {
	local $Test::Time::time = localtime->strptime('2016-05-01 12:00:00', '%Y-%m-%d %H:%M:%S')->epoch;
	my $entry1 = $service->create_new_entry(
		title => 'foo',
		body => 'bar',
		publish_at => localtime() + ONE_DAY,
		status => 'scheduled',
	);
	is $entry1->publish_at, '2016-05-02 03:00:00';
	my $entry2 = $service->create_new_entry(
		title => 'foo',
		body => 'bar',
		publish_at => localtime() + ONE_DAY * 2,
		status => 'scheduled',
	);
	is $entry2->publish_at, '2016-05-03 03:00:00';

	my $updated = $service->publish_scheduled_entries;
	is scalar @$updated, 0;

	sleep ONE_DAY + 1;

	my $updated = $service->publish_scheduled_entries;
	is scalar @$updated, 1;

	$entry1 = get_entry($entry1->id);
	is $entry1->status, 'public';

	work('Nogag::Worker::PostEntry');

	sleep ONE_DAY + 1;

	my $updated = $service->publish_scheduled_entries;
	is scalar @$updated, 1;

	$entry2 = get_entry($entry2->id);
	is $entry2->status, 'public';

	work('Nogag::Worker::PostEntry');
};
done_testing;
