package Nogag;

use strict;
use warnings;

use Nogag::Base;
use Nogag::Time;

use parent qw(Nogag::Base);

our @EXPORT = qw(config throw);

route "/" => sub {
	my ($r) = @_;

	my $entries = $r->dbh->select(q{
		SELECT * FROM entries
		ORDER BY sort_time DESC
		LIMIT 7 OFFSET 0
	}, {
	});

	my $count = $r->dbh->value('SELECT count(*) FROM entries');

	$r->stash(entries => $entries);
	$r->stash(count => $count);

	$r->html('index.html');
};

route "/login" => sub {
	my ($r) = @_;

	if ($r->req->method eq 'POST') {
		if ($r->req->param('password') eq config->param('password')) {
			$r->session->set('auth' => 1);
			throw code => 302, location => '/';
		} else {
			$r->stash('error' => 'Invalid Password');
		}
	}

	$r->html('login.html');
};

route "/edit" => sub {
	my ($r) = @_;
	return $r->json({ error => 'require authentication' }) unless $r->has_auth;

	$r->json(+{
		foo => 'bar'
	});
};

1;
