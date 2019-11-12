package Nogag::External::GooglePhotos;

use HTTP::Request::Common;
use URI;
use JSON::XS;
use LWP::UserAgent;
use Log::Minimal;
use Path::Class;

sub new {
	my ($class, %opts) = @_;
	my $self = bless {
		%opts,
	}, $class;
	$self->{ua} //= do {
		my $ua = LWP::UserAgent->new;
		$ua->timeout(10);
		$ua->agent($0);
		$ua;
	};
	$self;
}

sub oauth {
	my ($self, $callback) = @_;
	$callback ||= sub {
		my $uri = shift;
		printf "Access to authorization: %s\n", $uri;
		printf "Input authorization code: ";
		my $code = <>;
		chomp $code;
		$code;
	};

	if ($self->_access_token) {
		return;
	}

	my $authorize_uri = URI->new('https://accounts.google.com/o/oauth2/auth');
	$authorize_uri->query_form(
		response_type => 'code',
		client_id     => $self->{oauth}->{client_id},
		redirect_uri  => $self->{oauth}->{redirect_uri},
		scope         => 'https://www.googleapis.com/auth/photoslibrary.readonly',
	);

	my $code = $callback->($authorize_uri);

	my $token_uri = URI->new('https://accounts.google.com/o/oauth2/token');

	my $res = $self->{ua}->post($token_uri, {
		code          => $code,
		client_id     => $self->{oauth}->{client_id},
		client_secret => $self->{oauth}->{client_secret},
		redirect_uri  => $self->{oauth}->{redirect_uri},
		grant_type    => 'authorization_code',
	});

	my $data = decode_json $res->content;
	$data->{error} and die $data->{error};

	$self->{config}->{access_token}  = $data->{access_token};
	$self->{config}->{refresh_token} = $data->{refresh_token};
	$self->{config}->{expire}        = time + $data->{expires_in};
}

sub _refresh {
	my ($self) = @_;

	my $token_uri = URI->new('https://accounts.google.com/o/oauth2/token');

	my $res = $self->{ua}->post($token_uri, {
		client_id     => $self->{oauth}->{client_id},
		client_secret => $self->{oauth}->{client_secret},
		refresh_token => $self->{config}->{refresh_token},
		grant_type    => 'refresh_token',
	});

	if ($res->is_success) {
		my $data = decode_json $res->content;
		$self->{config}->{access_token}  = $data->{access_token};
		$self->{config}->{expire}        = time + $data->{expires_in};
		1;
	} else {
		undef $self->{config}->{access_token};
		undef $self->{config}->{expire};
		0;
	}
}

sub _access_token {
	my ($self) = @_;
	if (time > ($self->{config}->{expire} || 0)) {
		$self->_refresh;
	}
	$self->{config}->{access_token};
}

sub _request {
	my ($self, $req) = @_;
	$req->header('Authorization' => 'Bearer ' . $self->_access_token);
	$req->header('GData-Version' => '2');
	my $res = $self->{ua}->request($req);
	if ($res->is_success) {
		$res->content;
	} else {
		die $res->content;
	}
}

1;
