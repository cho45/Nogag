package Nogag::Worker::PostBuffer;

use utf8;
use strict;
use warnings;

use Nogag;
use Nogag::Service::Trackback;
use Nogag::Service::Cache;

use LWP::Simple qw($ua);
use HTTP::Request::Common;
use JSON::XS;
use Log::Minimal;

use parent qw(TheSchwartz::Worker);

sub work {
	my $class = shift;
	my TheSchwartz::Job $job = shift;
	local $Log::Minimal::AUTODUMP = 1;

	my $r = Nogag->new({});
	my $entry = $job->arg->{entry};

	# https://buffer.com/developers/apps
	my $token = config->param('buffer_access_token');

	my $res = $ua->request(GET 'https://api.bufferapp.com/1/profiles.json', 'Authorization' => 'Bearer ' . $token);
	unless ($res->is_success) {
		die $res->decoded_content;
	}

	my $profiles = decode_json $res->decoded_content;
	infof("[$class] Buffer %d profiles", scalar @$profiles);

	# XXX
	# $profiles = [ $profiles->[0] ];

	my $form_data = [
		(map { ('profile_ids[]' => $_->{id}) } grep { $_->{service} eq 'twitter' } @$profiles),

		'text' => $entry->title_for_permalink . "\n" . $r->absolute($entry->path),
		'media[link]' => $r->absolute($entry->path),
		'media[title]' => $entry->title_for_permalink,
		'media[description]' => $entry->summary,
		'media[photo]' => $entry->image,
		# 	'scheduled_at' => time() + 60 * 60 * 24 * 7
	];
	infof("[$class] Post %s", $form_data);

	my $res = $ua->request(POST 'https://api.bufferapp.com/1/updates/create.json', $form_data, 'Authorization' => 'Bearer ' . $token);

	my $result = decode_json $res->decoded_content;
	infof("[$class] Buffer result %s", $result);

	$job->completed;
}


1;
__END__
