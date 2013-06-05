package Nogag::Base;

use utf8;
use strict;
use warnings;
use parent qw(Exporter::Lite);

use Router::Simple;
use Try::Tiny;
use Path::Class;
use Digest::HMAC_SHA1 qw(hmac_sha1_hex);
use URI::Escape;

use Plack::Session;

use Nogag::Config;
use Nogag::DBI;
use Nogag::Request;
use Nogag::Response;
use Nogag::Exception;
use Nogag::Views;

our @EXPORT = qw(config route throw);

our $router = Router::Simple->new;

sub throw (%) { Nogag::Exception->throw(@_) }
sub route ($$) { $router->connect(shift, { action => shift }) }

sub new {
	my ($class, $env) = @_;
	my $req = Nogag::Request->new($env);
	my $res = Nogag::Response->new(200);

	bless {
		req => $req,
		res => $res,
	}, $class;
}

sub before_dispatch {
	my ($r) = @_;
	if ($r->req->method eq 'POST') {
		my $sk = $r->req->param('sk') or throw code => 400, message => 'Require session key';
		if ($r->sk ne $sk) {
			throw code => 400, message => 'Invalid session key';
		}
	}

	$r->res->header('X-Frame-Options'  => 'DENY');
	$r->res->header('X-XSS-Protection' => '1');
}

sub after_dispatch {
	my ($r) = @_;
}

sub run {
	my ($r) = @_;
	eval {
		my ($dest, $route) = $router->routematch($r->req->env);
		if ($dest) {
			my $action = delete $dest->{action};
			$r->req->path_parameters(%$dest);

			$r->before_dispatch;

			if (ref($action) eq 'CODE') {
				$action->(local $_ = $r);
			} else {
				my ($module, $method) = split /\s+/, $action;
				$module->use or die $@;
				$method ||= 'default';
				$module->$method($r);
			}
		} else {
			throw code => 404, message => 'Action not Found';
		}
	};
	if (my $e = $@) {
		if (try { $e->isa('Nogag::Exception') }) {
			$r->res->code($e->{code});
			$r->res->header('X-Message' => $e->{message}) if $e->{message};
			$r->res->header('Location' => $e->{location}) if $e->{location};
			$r->stash(error => $e);
			$r->stash(title => sprintf('Error %s', $e->{code}));
			$r->html('index.html');
		} else {
			$r->res->code(500);
			$r->res->header('X-Message' => "$e");
			$r->res->header('Content-Type', 'text/plain');
			$r->res->content('500');
		}
	}

	$r->after_dispatch;

	$r;
}

sub config_param {
	config->param($_[1]);
}

sub req { $_[0]->{req} }
sub res { $_[0]->{res} }

sub session {
	$_[0]->{session} //= do {
		$_[0]->{req}->env->{'psgix.session'} ? Plack::Session->new($_[0]->{req}->env) : ''
	};
}

sub dbh {
	$_[0]->{dbh} //= do {
		DBI->connect('dbi:SQLite:' . config->param('db'), "", "", {
			RaiseError => 1,
			sqlite_see_if_its_a_number => 1,
			sqlite_unicode => 1,
		});
	};
}

sub setup_schema {
	my ($class) = @_;
	my $schema = file('db/schema.sql')->slurp;
	my $dbh = DBI->connect('dbi:SQLite:' . config->param('db'));
	$dbh->do($_) for split /;/, $schema;
}

sub sk {
	my ($r) = @_;
	hmac_sha1_hex($r->session->id, config->param('password'));
}

sub stash {
	my ($r, $key, $val) = @_;
	$r->{stash} ||= {};

	if (defined $val) {
		$r->{stash}->{$key} = $val;
	} elsif (defined $key) {
		$r->{stash}->{$key};
	} else {
		$r->{stash};
	}
}

sub has_auth {
	my ($r) = @_;
	$r->session->get('auth') 
}

sub require_auth {
	my ($r) = @_;
	$r->has_auth or throw code => 302, message => 'Require authentication', location => '/login?redirect=' . uri_escape($r->req->uri);
}

sub absolute {
	my ($r, $path) = @_;
	my $uri = $r->req->uri->clone;
	$uri->path_query($path);
	"$uri";
}

sub is_smartphone {
	my ($r) = @_;
	$r->{_is_smartphone} //= do {
		$r->req->user_agent =~ /Android|iPhone|iPod/;
	};
}

1;
__END__
