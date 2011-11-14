package Nogag;

use strict;
use warnings;

use Nogag::Base;
use Nogag::Time;
use Encode;

use parent qw(Nogag::Base);

our @EXPORT = qw(config throw);

route "/" => sub {
	my ($r) = @_;

	my $page = $r->req->number_param('page') || 1;

	my $entries = $r->dbh->select(q{
		SELECT * FROM entries
		ORDER BY sort_time DESC
		LIMIT :limit OFFSET :offset
	}, {
		limit  => config->param('entry_per_page'),
		offset => ($page - 1) * config->param('entry_per_page'),
	});

	my $count = $r->dbh->value('SELECT count(*) FROM entries');

	$r->stash(entries => $entries);
	$r->stash(count => $count);
	$r->stash(page => $page);

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
