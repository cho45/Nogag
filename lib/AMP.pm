package AMP;

use utf8;
use strict;
use warnings;

use HTML::HTML5::Parser;
use HTML::HTML5::DOM;
use Furl;
use Image::Size;

sub new {
	my ($class, %args) = @_;
	bless {
		%args,
		ua => Furl->new(agent => 'Nogag', timeout => 10),
		collected_styles => [],
		id_for_style_attr => 1,
	}, $class;
}

sub filter {
	my ($self, $html) = @_;
	my $parser = HTML::HTML5::Parser->new;
	my $doc = $parser->parse_string(qq{<!doctype html><head><title>x</title></head><body><div id="__amp_fragment">$html</div>});
	XML::LibXML::Augment->rebless($doc);
	my $collected_styles = $self->{collected_styles};

	for my $ele ( $doc->querySelectorAll('style') ) {
		XML::LibXML::Augment->rebless($ele);
		if ($ele->hasAttribute('amp-custom')) {
			next;
		}
		my $style = $ele->innerHTML;
		$style =~ s{!important}{}g;
		push @$collected_styles, $style;
		$ele->parentNode->removeChild($ele);
	}

	for my $ele ( $doc->querySelectorAll('*[style]') ) {
		my $inline = $ele->getAttribute('style') || $ele->getAttributeNS('http://www.w3.org/2000/svg', 'style');
		$ele->removeAttribute('style');
		$ele->removeAttributeNS('http://www.w3.org/2000/svg', 'style');
		XML::LibXML::Augment->rebless($ele);

		my $class = sprintf('_i%s', $self->{id_for_style_attr}++);
		$ele->setAttribute('class', join(' ', $class, split /\s+/, $ele->getAttribute('class') // '' ));

		push @$collected_styles, ".$class { $inline }";
	}

	for my $script ( $doc->querySelectorAll('script') ) {
		my $src = $script->getAttribute('src');
		if ($src =~ qr{^https?://gist\.github\.com/(.+)\.js}) {
			my $raw_url = "https://gist.githubusercontent.com/$1/raw";
		}
		$script->parentNode->removeChild($script);
	}

	for my $img ( $doc->querySelectorAll('img') ) {
		if (!($img->hasAttribute('width') && $img->hasAttribute('height'))) {
			my $src = $img->getAttribute('src');
			my $res = $self->{ua}->get($src, [
				Range => 'bytes=0-4096'
			]);
			my ($w, $h) = imgsize(\$res->content);
			if (!$w) {
				use Data::Dumper;
				warn Dumper $res ;
				$w = 900; $h = 500;
			}

			$img->setAttribute('width', $w);
			$img->setAttribute('height', $h);
		}

		my $amp = $doc->createElement('amp-img');
		for my $attr (qw/src srcset alt width height/) {
			$img->hasAttribute($attr) or next;
			my $val = $img->getAttribute($attr);
			$amp->setAttribute($attr, $val);
		}

		$amp->setAttribute('layout', 'responsive');

		$img->parentNode->replaceChild($amp, $img);
	}

	for my $ele ( $doc->querySelectorAll('*[focusable]') ) {
		$ele->removeAttributeNS('http://www.w3.org/2000/svg', 'focusable');
	}

	my $container = $doc->querySelector('div[id=__amp_fragment]');
	XML::LibXML::Augment->rebless($container);
	
	$container->innerHTML,
}

sub collected_styles {
	join("\n", @{$_[0]->{collected_styles}});
}



1;
__END__
