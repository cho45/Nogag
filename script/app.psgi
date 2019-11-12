# vim:ft=perl:
use strict;
use warnings;
use lib 'lib';
use lib glob 'modules/*/lib';

use UNIVERSAL::require;
use Path::Class;
use File::Spec;
use POSIX;
use Cache::Null;
use Data::MessagePack;

use Plack::Builder;
use Plack::Session::State::Cookie;
use Plack::Session::Store::File;
use Plack::Session::Store::Cache;

use Cache::Memcached::Fast::Safe;

use Nogag;
use lib config->root->subdir('lib')->absolute.q();

POSIX::setlocale(&POSIX::LC_ALL, "C");

#{
#	use Parallel::Prefork;
#	my $name = $0;
#	my $orig_new = \&Parallel::Prefork::new;
#	no warnings 'redefine';
#	*Parallel::Prefork::new = sub {
#		my ($class, $opts) = @_;
#		$opts->{before_fork} = sub {
#			$0 = "$name (worker)"
#		};
#		$opts->{after_fork} = sub {
#			$0 = "$name (master)"
#		};
#		$orig_new->($class, $opts);
#	};
#};

Nogag->setup_schema;

builder {
	enable "Plack::Middleware::Static",
		path => qr{^/(images|js|css)/},
		root => config->root->subdir('static');

	enable "Plack::Middleware::ReverseProxy";
	enable_if {
		# disable static like path
		$_[0]->{PATH_INFO} !~ m{^/api/(similar|exif)}
	} "Plack::Middleware::Session",
		state => Plack::Session::State::Cookie->new(
			session_key => 's',
			expires => 7776000,
			httponly => 1,
			samesite => 'lax',
			secure => 1,
			
		),
		store => Plack::Session::Store::Cache->new(
			cache => Cache::Memcached::Fast::Safe->new(config->param('session')),
		);

	sub {
		Nogag->new(shift)->run->res->finalize;
	};
};


