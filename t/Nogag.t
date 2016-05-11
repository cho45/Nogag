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

my $postprocess = postprocess();

subtest base => sub {
	my $app = Nogag->new(GET('/')->to_psgi);
	isa_ok $app->req, "Plack::Request";
	isa_ok $app->res, "Plack::Response";
};

subtest path_parameters => sub {
	local $Nogag::Base::router = Router::Simple->new;
	Nogag::route('/:foo/:bar' => sub {
		my ($r) = @_;
		is $r->req->path_parameters->{foo}, 'hoge';
		is $r->req->path_parameters->{bar}, 'fuga';
		is $r->req->param('foo'), 'qqq';
		is $r->req->param('bar'), 'fuga';
	});
	my $r = Nogag->new(GET('/hoge/fuga?foo=qqq')->to_psgi)->run;
};

subtest xframeoptions => sub {
	local $Nogag::Base::router = Router::Simple->new;

	Nogag::route('/' => sub {
		my ($r) = @_;
		$r->res->content('foobar');
	});

	Nogag::route('/sameorigin' => sub {
		my ($r) = @_;
		$r->res->header('X-Frame-Options' => 'SAMEORIGIN');
	});

	Nogag::route('/no' => sub {
		my ($r) = @_;
		$r->res->headers->remove_header('X-Frame-Options');
	});

#	{
#		my $r = Nogag->new(GET('/')->to_psgi)->run;
#		is $r->res->header('X-Frame-Options'), 'DENY';
#	};

	{
		my $r = Nogag->new(GET('/sameorigin')->to_psgi)->run;
		is $r->res->header('X-Frame-Options'), 'SAMEORIGIN';
	};

	{
		my $r = Nogag->new(GET('/no')->to_psgi)->run;
		is $r->res->header('X-Frame-Options'), undef;
	};
};

subtest login => sub {
	my $mech = mechanize();

	{
		my $res = $mech->get("/", 'Cache-Control' => 'no-cache');
		is($res->code, 404);
		like($res->content, qr{data-auth=""});
	};

	$mech->login;

	{
		my $res = $mech->get("/", 'Cache-Control' => 'no-cache');
		is($res->code, 404);
		like($res->content, qr{data-auth="true"});
	};

	$mech->logout;

	{
		my $res = $mech->get("/", 'Cache-Control' => 'no-cache');
		is($res->code, 404);
		like($res->content, qr{data-auth=""});
	};
};

subtest edit => sub {
	local *Nogag::Service::Cache::generate_cache_for_path = sub { note "generate_cache_for_path is disabled in this tests"; };

	my $mech = mechanize();
	{
		my $res = $mech->get("/", 'Cache-Control' => 'no-cache');
		is($res->code, 404);
	}

	{
		my $res = $mech->get('/api/edit');
		is($res->code, 200);
		my $json = decode_json($res->content);
		is($json->{error}, 'require authentication');
		ok(!$json->{html});
	};

	$mech->login;

	my $entry = get_entry($mech->edit(
		title => 'test',
		body => 'test',
		location => '/',
	));

	{
		my $mech = mechanize();
		$mech->get_and_cache_created_ok('/');
		$mech->get_and_cache_created_ok($entry->path);
	};

	subtest permalink_cache => sub {
		my $entry_id = $mech->edit(
			title => 'test',
			body => 'test',
			location => '/',
		);
		my $entry = get_entry($entry_id);

		{
			my $mech = mechanize();
			$mech->get_and_cache_created_ok('/');
			$mech->get_and_cache_created_ok($entry->path);
		};

		{
			$mech->edit(
				id => $entry->id,
				title => 'test',
				body => 'test',
				location => '/',
			);

			{
				my $mech = mechanize();
				$mech->get_and_cache_created_ok('/');
				$mech->get_and_cache_created_ok($entry->path);
			};
		};
	};

	{
		my $mech = mechanize();
		$mech->get_cached_ok($entry->path);
	};

	subtest category_cache => sub {
		my $entry_id = $mech->edit(
			title => '[tech] test',
			body => 'test',
			location => '/',
		);
		my $entry = get_entry($entry_id);

		{
			my $mech = mechanize();
			$mech->get_and_cache_created_ok('/');
			$mech->get_and_cache_created_ok('/tech/');
			$mech->get_and_cache_created_ok($entry->path);
		};

		{
			$mech->edit(
				id => $entry->id,
				title => '[tech] test',
				body => 'test',
				location => '/',
			);

			{
				my $mech = mechanize();
				$mech->get_and_cache_created_ok('/');
				$mech->get_and_cache_created_ok('/tech/');
				$mech->get_and_cache_created_ok($entry->path);
			};
		};
	};
};

subtest basic_pages => sub {
	cleanup_database;

	my $mech = mechanize();
	$mech->login;

	my $entry1 = get_entry($mech->edit(
		title => 'test',
		body => 'test',
		location => '/',
	));

	my $entry2 = get_entry($mech->edit(
		title => '[tech] test',
		body => 'test',
		location => '/',
	));

	my $admin = $mech;
	my $guest = mechanize();

	my ($res, $tree);
	for my $m ($admin, $guest) {
		$m->get_dispatched_ok('/login','/login');
		$m->get_dispatched_ok('/robots.txt','/robots.txt');
		$m->get_dispatched_ok('/sitemap.xml','/sitemap.xml');
		$m->get_dispatched_ok('/archive','/archive');

		$res = $m->get_dispatched_ok('/feed','/feed');
		unlike $res->content, qr"@{[$entry1->path('/')]}";
		like $res->content, qr"@{[$entry2->path('/')]}";

		$res = $m->get_dispatched_ok('/','/');
		$tree = tree($res->content);
		ok $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		ok $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');

		$res = $m->get_dispatched_ok('/tech/','/:category_name/');
		$tree = tree($res->content);
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		ok $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');

		$res = $m->get_dispatched_ok($entry1->path('/'),'/{path:.+}');
		$tree = tree($res->content);
		ok $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');

		$res = $m->get_dispatched_ok($entry1->date->strftime('/%Y/%m/%d/'),'/{year:[0-9]{4}}/{month:[0-9]{2}}/{day:[0-9]{2}}/');
		$tree = tree($res->content);
		ok $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');

		$res = $m->get_dispatched_ok($entry1->date->strftime('/%Y/%m/'),'/{year:[0-9]{4}}/{month:[0-9]{2}}/');
		$tree = tree($res->content);
		ok $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');

		$res = $m->get_dispatched_ok($entry2->path('/'),'/{path:.+}');
		$tree = tree($res->content);
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		ok $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');
	}
};

subtest trackbacks => sub {
	cleanup_database;
	my $mech = mechanize();
	$mech->login;

	my $entry1 = get_entry($mech->edit(
		title => 'test',
		body => 'test',
		location => '/',
	));

	my $entry2 = get_entry($mech->edit(
		title => 'test',
		body => 'test https://lowreal.net/' . $entry1->path . ' ',
		location => '/',
	));

	my $entry3 = get_entry($mech->edit(
		title => 'test',
		body => 'test https://lowreal.net/' . $entry1->path . ' ',
		location => '/',
	));

	{
		my $res = $mech->get($entry1->path('/'));
		ok tree($res->content)->exists('//*[@class="content trackbacks"]//a[contains(@href, "'.$entry2->path('/').'")]');
		ok tree($res->content)->exists('//*[@class="content trackbacks"]//a[contains(@href, "'.$entry3->path('/').'")]');
	};

	$entry2 = get_entry($mech->edit(
		id => $entry2->id,
		title => 'test',
		body => 'test removed',
	));

	{
		my $res = $mech->get($entry1->path('/'));
		ok !tree($res->content)->exists('//*[@class="content trackbacks"]//a[contains(@href, "'.$entry2->path('/').'")]');
		ok tree($res->content)->exists('//*[@class="content trackbacks"]//a[contains(@href, "'.$entry3->path('/').'")]');
	};
};

subtest pager => sub {
	cleanup_database;
	my $guard = config->local(entry_per_page => 2);

	local $Test::Time::time = localtime->strptime('2016-05-01', '%Y-%m-%d')->epoch;

	my $mech = mechanize();
	$mech->login;

	# 2016-05-01
	my $entry1 = get_entry($mech->edit(
		title => '[tech] test',
		body => 'test',
		location => '/',
	));
	note "entry1->created_at ". $entry1->created_at;

	sleep ONE_DAY;

	# 2016-05-02
	my $entry2 = get_entry($mech->edit(
		title => '[tech] test',
		body => 'test',
		location => '/',
	));
	note "entry2->created_at ". $entry2->created_at;

	sleep ONE_DAY;

	# 2016-05-03
	my $entry3 = get_entry($mech->edit(
		title => '[tech] test',
		body => 'test',
		location => '/',
	));
	note "entry3->created_at ". $entry3->created_at;

	sleep ONE_DAY;

	# 2016-05-04
	my $entry4 = get_entry($mech->edit(
		title => '[tech] test',
		body => 'test',
		location => '/',
	));
	note "entry4->created_at ". $entry4->created_at;

	subtest 'index' => sub {
		my ($res, $tree);

		$res = $mech->get_dispatched_ok('/','/');
		$tree = tree($res->content);
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry4->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry3->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		is $tree->findvalue('//a[@rel="next"]/@href'), '/?page=20160502';

		$res = $mech->get_dispatched_ok('/?page=20160503','/');
		$tree = tree($res->content);
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry4->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry3->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		is $tree->findvalue('//a[@rel="next"]/@href'), '/?page=20160501';

		$res = $mech->get_dispatched_ok('/?page=20160502','/');
		$tree = tree($res->content);
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry4->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry3->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		ok !$tree->exists('//a[@rel="next"]/@href');
	};

	subtest 'category' => sub {
		my ($res, $tree);

		$res = $mech->get_dispatched_ok('/tech/','/:category_name/');
		$tree = tree($res->content);
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry4->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry3->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		is $tree->findvalue('//a[@rel="next"]/@href'), '/tech/?page=20160502000000';

		$res = $mech->get_dispatched_ok('/tech/?page=20160502000000','/:category_name/');
		$tree = tree($res->content);
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry4->path('/').'")] ');
		ok !$tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry3->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry2->path('/').'")] ');
		ok  $tree->exists('//a[@class="bookmark" and contains(@href,"'.$entry1->path('/').'")] ');
		ok !$tree->exists('//a[@rel="next"]/@href');
	};
};


done_testing;
