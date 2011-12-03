package Nogag::API;

use utf8;
use strict;
use warnings;

use Nogag;
use JSON::XS;
use XML::LibXML;
use LWP::Simple qw($ua);

sub kousei {
	my ($class, $r) = @_;
	return $r->json({ error => 'require authentication' }) unless $r->has_auth;

	my $uri = URI->new('http://jlp.yahooapis.jp/KouseiService/V1/kousei');
	$uri->query_form(
		appid    => config->param('yahoo_jp_appid'),
		sentence => $r->req->string_param('sentence'),
	);

	my $api = $ua->get($uri);
	my $xml = $api->content;

	my $doc = XML::LibXML->load_xml( string => $xml );
	my $xpc = XML::LibXML::XPathContext->new($doc);
	$xpc->registerNs('k', 'urn:yahoo:jp:jlp:KouseiService');
	my $result = [];
	for my $node (@{ $xpc->findnodes('/k:ResultSet/k:Result') }) {
		push @$result, +{
			start   => $xpc->findvalue('k:StartPos', $node) + 0,
			length  => $xpc->findvalue('k:Length', $node) + 0,
			surface => $xpc->findvalue('k:Surface', $node),
			word    => $xpc->findvalue('k:ShitekiWord', $node),
			info    => $xpc->findvalue('k:ShitekiInfo', $node),
		};
	}

	$r->json(+{
		status => 200,
		result => $result,
	});
}



1;
__END__
