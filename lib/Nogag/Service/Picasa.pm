package Nogag::Service::Picasa;

use HTTP::Request::Common;
use URI;
use JSON::XS;
use LWP::UserAgent;
use Log::Minimal;
use Path::Class;

use Nogag::Config;
use Nogag::External::Picasa;

use parent qw(Nogag::Service);

sub client {
	my ($self) = @_;
	$self->{client} //= do {
		my $config = $self->load_config;

		my $picasa = Nogag::External::Picasa->new(
			config => {
				access_token => $config->{access_token},
				refresh_token => $config->{refresh_token},
				expire => $config->{expire},
			},
			oauth => {
				client_id => config->param('picasa_client_id'),
				client_secret => config->param('picasa_client_secret'),
				redirect_uri  => "urn:ietf:wg:oauth:2.0:oob",
			}
		);
	}
}

sub load_config {
	my ($self) = @_;
	my $config = $self->r->config_dbh->select(q{
		SELECT * FROM oauth_client
		WHERE client_id = :client_id
	}, {
		client_id => config->param('picasa_client_id')
	})->[0] || {};
}

sub save_config {
	my ($self, $config) = @_;
	$self->r->config_dbh->update(q{
		INSERT OR REPLACE INTO oauth_client
			(
				`client_id`,
				`access_token`,
				`refresh_token`,
				`expire`
			)
			VALUES
			(
				:client_id,
				:access_token,
				:refresh_token,
				:expire
			)
	}, {
		client_id => config->param('picasa_client_id'),
		access_token => $config->{access_token},
		refresh_token => $config->{refresh_token},
		expire => $config->{expire},
	});
}

sub authorize {
	my ($self, $cb) = @_;
	my $client = $self->client;
	$client->oauth($cb);
	$self->save_config($client->{config});
}

sub refresh {
	my ($self) = @_;
	my $client = $self->client;
	$client->_refresh;
	$self->save_config($client->{config});
}

sub extract_exif {
	my ($self, $target) = @_;
	my $exif = $self->r->dbh->select(q{
		SELECT * FROM exif
		WHERE uri = :uri
	}, {
		uri => $target
	})->[0];

	if (!$exif) {
		$exif = $self->_extract_exif($target);
		$self->r->dbh->update(q{
			INSERT INTO exif
				(
					`uri`,
					`original_uri`,
					`model`,
					`make`,
					`focallength`,
					`fnumber`,
					`iso`,
					`speed`
				)
				VALUES
				(
					:uri,
					:original_uri,
					:model,
					:make,
					:focallength,
					:fnumber,
					:iso,
					:speed
				)
		}, {
			uri => $target,
			%$exif
		});
	}

	$exif;
}

sub _extract_exif {
	my ($self, $target) = @_;
	#  Eg.: $target = "https://picasaweb.google.com/114431815111528304586/6379705403644016417#6379705404126052530";
	my ($user, $albumid, $photoid) = ($target =~ m{^https://picasaweb.google.com/([^/]+)/([^#/]+)#(\d+)});
	## XXX : invalid な albumid になることがある。存在してさえすればなんでもいいっぽいので適当に指定する。。。
	$albumid = '1000000428304586';
	unless ($user && $albumid && $photoid) {
		return {};
	}
	my $res = $self->client->_request(GET "https://picasaweb.google.com/data/feed/api/user/$user/albumid/$albumid/photoid/$photoid?alt=json&imgmax=d");
	my $data = decode_json($res);
	my $original_uri = $data->{feed}->{'media$group'}->{'media$content'}->[0]->{url};

	my $exif = $data->{feed}->{'exif$tags'};
	+{
		original_uri => $original_uri,
		model        => $exif->{'exif$model'}->{'$t'},
		make         => $exif->{'exif$make'}->{'$t'},
		focallength  => $exif->{'exif$focallength'}->{'$t'},
		fnumber      => $exif->{'exif$fstop'}->{'$t'},
		iso          => $exif->{'exif$iso'}->{'$t'},
		speed        => $exif->{'exif$exposure'}->{'$t'},
	}
}

1;
