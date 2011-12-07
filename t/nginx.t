use strict;
use warnings;
use lib lib => 't/lib' => glob 'modules/*/lib';

use File::Which;
use Data::Dumper;
use Path::Class;
use File::Temp;
use HTTP::Server::PSGI;
use HTTP::Request;
use LWP::UserAgent;
use URI;

use Test::More;
use Test::TCP;
use Test::Name::FromLine;

$ENV{PATH} = "$ENV{PATH}:/usr/local/sbin:/usr/sbin";
my $nginx = which('nginx') or plan skip_all => 'nginx is not found';

my $backend = Test::TCP->new(
	code => sub {
		my $port = shift;

		my $server = HTTP::Server::PSGI->new(
			host    => "127.0.0.1",
			port    => $port,
			timeout => 120,
		);

		$server->run(sub { [ 200, [ 'Content-Type' => 'text/plain' ], [ Dumper shift ] ] });
	}
);

my $proxy = Test::TCP->new(
	code => sub {
		my $port = shift;
		my $backend_port = $backend->port;
		my $temp = File::Temp::tempdir();

		my $conf = file('config/nginx.conf')->slurp;
		$conf =~ s{listen\s+\d+}{listen $port}g;
		$conf =~ s{access_log[^;]+;}{access_log $temp/access_log;}g;
		$conf =~ s{proxy_pass http://localhost:5001/;}{proxy_pass http://127.0.0.1:$backend_port;}g;

		my $fh = IO::File->new("$temp/nginx.conf", "w");
		print $fh qq{
			error_log $temp/error_log crit;
			lock_file $temp/lock_file;
			pid $temp/nginx.pid;

			events {
				worker_connections 1024;
			}

			http {
				$conf
			}
		};
		close $fh;

		exec "$nginx -c " . "$temp/nginx.conf" or die "cannot execute $nginx: $!";
	}
);

my $ua = LWP::UserAgent->new( max_redirect => 0 );
sub request {
	my ($method, $uri, $header, $content) = @_;
	$header ||= [];

	$uri = URI->new("$uri");

	push @$header, Host => $uri->host;

	$uri->host('127.0.0.1');
	$uri->port($proxy->port);

	my $res = $ua->request(HTTP::Request->new($method, "$uri", $header, $content));
	$res->{env} = do {
		no strict;
		no warnings;
		eval($res->content);
	};
	$res->{do} = sub { shift->(local $_ = $res) };
	$res;
}

sub path ($) {
	"http://lowreal.net:" . $proxy->port . shift;
}

subtest backend => sub {
	request(GET => 'http://lowreal.net/')->{do}->(sub {
		ok $_->{env}->{HTTP_X_FORWARDED_FOR};
		is $_->{env}->{HTTP_HOST}, 'lowreal.net';
	});
};

subtest redirect => sub {
	request(GET => 'http://lowreal.net/feed')->{do}->(sub {
		is $_->{env}->{HTTP_HOST}, 'lowreal.net';
		is $_->{env}->{PATH_INFO}, '/feed';
	});

	request(GET => 'http://lowreal.net/logs/latest')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/');
	});

	request(GET => 'http://lowreal.net/logs/latest.rdf')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/feed');
	});

	request(GET => 'http://lowreal.net/logs/latest.atom')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/feed');
	});

	request(GET => 'http://lowreal.net/blog/index.rdf')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/feed');
	});

	request(GET => 'http://lowreal.net/blog/index.atom')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/feed');
	});

	request(GET => 'http://lowreal.net/logs/2004/10/11.rdf')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/feed');
	});

	request(GET => 'http://lowreal.net/logs/2004/10/11.atom')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/feed');
	});

	request(GET => 'http://lowreal.net/logs/2004/10/11.html')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11');
	});

	request(GET => 'http://lowreal.net/logs/2004/10/11')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11');
	});

	request(GET => 'http://lowreal.net/logs/2004/10/11/')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11/');
	});

	request(GET => 'http://lowreal.net/logs/2004/10/11/1.html')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11/1');
	});

	request(GET => 'http://lowreal.net/logs/2004/10/11/1')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11/1');
	});

	request(GET => 'http://lowreal.net/blog/2004/10/11/1')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11/1');
	});

	request(GET => 'http://lowreal.net/blog/2004/10/11/')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11/');
	});

	request(GET => 'http://lowreal.net/2004/10/11')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/11/');
	});

	request(GET => 'http://lowreal.net/2004/10')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2004/10/');
	});

	request(GET => 'http://lowreal.net/2004/')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 302;
		is $_->header('Location'), path('/');
	});

	request(GET => 'http://lowreal.net/view-img/2006/mabinogi_2006_04_30_001.jpg')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/2006/mabinogi_2006_04_30_001.jpg');
	});

	request(GET => 'http://lowreal.net/photo')->{do}->(sub {
		ok !$_->{env};
		is $_->code, 301;
		is $_->header('Location'), path('/photo/');
	});
};

subtest files => sub {
	request(GET => 'http://lowreal.net/favicon.ico')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/apple-touch-icon.png')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/images/apple-touch-icon.png')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/css/style.css')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/js/nogag.js')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/files/hatena/dull/dull.css')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/2005/colors-canvas.xhtml')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/2006/0423-tsun.jpg')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '200';
	});

	request(GET => 'http://lowreal.net/lib/PlotKit/PlotKit_Packed.js')->{do}->(sub {
		ok !$_->{env};
		is $_->code, '404';
	});

	request(GET => 'http://lowreal.net/', [ Cookie => 's=403c1bc00ea043548f2275d538e1d26b422ca95c' ])->{do}->(sub {
		ok !$_->{env};
		is $_->code, '403';
	});

#	request(GET => 'http://lowreal.net/', [ 'User-Agent' => 'Mozilla/5.0 (compatible; Yahoo Pipes 2.0; +http://developer.yahoo.com/yql/provider) Gecko/20090729 Firefox/3.5.2'])->{do}->(sub {
#		ok !$_->{env};
#		is $_->code, '403';
#	});
};

done_testing;
