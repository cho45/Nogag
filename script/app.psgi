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

my $MessagePack = Data::MessagePack->new;
$MessagePack->canonical;

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


#	enable "Plack::Middleware::StaticShared",
#		cache => Cache::Null->new,
#		base => config->root->subdir('static'),
#		binds => [
#			{
#				prefix       => '/.shared.js',
#				content_type => 'text/javascript; charset=utf-8',
#			},
#			{
#				prefix       => '/.shared.css',
#				content_type => 'text/css; charset=utf-8',
#				filter       => sub {
#					s{\s+}{ }g;
#					$_;
#				}
#			},
#		],
#		verifier => sub {
#			my ($version, $prefix) = @_;
#			$version =~ /^[0-9a-z]+$/
#		};

	enable "Plack::Middleware::ReverseProxy";
	enable "Plack::Middleware::Session",
		state => Plack::Session::State::Cookie->new(
			session_key => 's',
			expires => 60 * 60 * 24 * 365,
		),
		store => Plack::Session::Store::File->new(
			dir => config->root->subdir('session').q(),
			serializer   => sub {
				my ($session, $file) = @_;
				return unless %$session;
				my $fh = file($file)->openw;
				print $fh $MessagePack->pack($session);
				close $fh;
			},
			deserializer => sub {
				my ($file) = @_;
				eval {
					$MessagePack->unpack(scalar file($file)->slurp)
				} || +{}
			},
		);

	sub {
		Nogag->new(shift)->run->res->finalize;
	};
};


