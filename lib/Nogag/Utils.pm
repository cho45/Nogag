package Nogag::Utils;

use utf8;
use strict;
use warnings;

use Encode;
use LWP::Simple qw($ua);
use Log::Minimal;

sub postprocess {
	my ($class, $html) = @_;
	infof("postprocess");
	my $res = $ua->post('http://127.0.0.1:13370/', Content => encode_utf8 $html);
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
	my $res = $ua->post('http://127.0.0.1:13370/?minifyOnly=1', Content => encode_utf8 $html);
	if ($res->is_success) {
		return $res->decoded_content;
	} else {
		critf("failed %p", $res);
		return $html;
	}
}

1;
__END__
