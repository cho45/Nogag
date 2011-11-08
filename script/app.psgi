# vim:ft=perl:
use strict;
use warnings;
use lib 'lib';
use lib glob 'modules/*/lib';

use UNIVERSAL::require;
use Path::Class;
use File::Spec;

use Plack::Builder;
use Plack::Session::State::Cookie;
use Plack::Session::Store::File;

use Nogag;

if (not -e config->param('db')) {
	Nogag->setup_schema;
}

builder {
	enable "Plack::Middleware::Static",
		path => qr{^/(images|js|css)/},
		root => config->root->subdir('static');

	enable "Plack::Middleware::ReverseProxy";
	enable "Plack::Middleware::Session",
		state => Plack::Session::State::Cookie->new(
			session_key => 's',
			expires => undef,
		),
		store => Plack::Session::Store::File->new(
			dir          => config->root->subdir('session').q(),
		);

	sub {
		Nogag->new(shift)->run->res->finalize;
	};
};


