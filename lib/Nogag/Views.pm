package Nogag::Views;

use utf8;
use strict;
use warnings;

use Exporter::Lite;
our @EXPORT = qw(html json redirect render email);

use Text::Xslate qw(mark_raw);
use JSON::XS;
use Encode;
use HTML::Trim;
use HTML::Packer;
use JavaScript::Packer;
use CSS::Packer;
use Text::Overflow qw(ellipsis);

use Nogag::Config;
use Nogag::Utils;

my $XSLATE = Text::Xslate->new(
	syntax   => 'TTerse',
	path     => [ config->root->subdir('templates') ],
	cache    => 1,
	function => {
		trim => sub {
			my ($len) = @_;

			sub {
				ellipsis(shift || '', $len);
				# HTML::Trim::vtrim(shift || '', $len, '…');
			}
		},
	},
);
#{
#	no warnings 'redefine';
#	*Text::Xslate::slurp_template = sub {
#		my ($self, $input_layer, $fullpath) = @_;
#		my $source = sub {
#			if (ref $fullpath eq 'SCALAR') {
#				return $$fullpath;
#			} else {
#				open my($source), '<' . $input_layer, $fullpath
#					or $self->_error("LoadError: Cannot open $fullpath for reading: $!");
#				local $/;
#				return scalar <$source>;
#			}
#		}->();
#		if ($fullpath =~ /\.html$/) {
#			$source =~ s{^\s+}{}gm;
#			$source =~ s{\n\n+}{\n}g;
#			return $source;
#		} else {
#			return $source;
#		}
#	};
#	$XSLATE->load_file($_) for qw{
#		index.html
#		_article.html
#		_adsense.html
#	};
#};

sub render {
	my ($r, $name, $vars) = @_;
	$vars = {
		%{ $r->stash },
		%{ $vars || {} },
		r => $r,
	};

	my $content = $XSLATE->render($name, $vars);
}

sub html {
	my ($r, $name, $vars) = @_;
	my $html = $r->render($name, $vars);
	$html =~ s{(<img src="https://[^.]+\.googleusercontent\.com/.+?)/s\d+/(.+?")}{$1/s2048/$2}g;
	# $html = Nogag::Utils->minify($html);
	$r->res->content_type('text/html; charset=utf-8');
	$r->res->content(encode_utf8 $html);
}

sub json {
	my ($r, $vars, %opts) = @_;
	my $body = JSON::XS->new->ascii(1)->encode($vars);
	$r->res->content_type('application/json; charset=utf-8');
	$r->res->content($body);
}

sub redirect {
	my ($r, $location, $code) = @_;
	$code ||= 302;
	$r->res->status($code);
	$r->res->header('Location' => $location);
}

1;
__END__
