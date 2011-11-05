use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Name::FromLine;

use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Router::Simple;

BEGIN { use_ok( 'Nogag' ); }

use Nogag::Test;

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

	{
		my $r = Nogag->new(GET('/')->to_psgi)->run;
		is $r->res->header('X-Frame-Options'), 'DENY';
	};

	{
		my $r = Nogag->new(GET('/sameorigin')->to_psgi)->run;
		is $r->res->header('X-Frame-Options'), 'SAMEORIGIN';
	};

	{
		my $r = Nogag->new(GET('/no')->to_psgi)->run;
		is $r->res->header('X-Frame-Options'), undef;
	};
};

subtest default => sub {
	my $mech = mechanize();
	$mech->get_ok("/");
};

done_testing;
