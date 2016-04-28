package Nogag::Utils;

use utf8;
use strict;
use warnings;

use Encode;
use LWP::Simple qw($ua);
use Log::Minimal;
use Nogag::Config;

sub postprocess {
	my ($class, $html) = @_;
	infof("postprocess");
	my $uri = config->param('postprocess')->clone;
	$uri->path('/');
	my $res = $ua->post("$uri", Content => encode_utf8 $html);
	if ($res->is_success) {
		return $res->decoded_content;
	} else {
		critf("failed %p", $res);
		return $html;
	}
}

sub minify {
	my ($class, $html) = @_;
	infof("minify");
	my $uri = config->param('postprocess')->clone;
	$uri->path('/');
	$uri->query_form(minifyOnly => 1);
	my $res = $ua->post("$uri", Content => encode_utf8 $html);
	if ($res->is_success) {
		return $res->decoded_content;
	} else {
		critf("failed %p", $res);
		return $html;
	}
}

1;
__END__
