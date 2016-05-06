use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Name::FromLine;

use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Router::Simple;
use JSON;

use Nogag::Test;
use Nogag;

my $postprocess = postprocess();
my $config_guard = config->local(
	postprocess    => URI->new('http://127.0.0.1:' . $postprocess->port),
);

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
};

done_testing;
