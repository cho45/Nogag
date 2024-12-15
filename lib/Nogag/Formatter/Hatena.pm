package Nogag::Formatter::Hatena;

use utf8;
use strict;
use warnings;

use Text::Xatena;
use Cache::FileCache;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->timeout(5);

my $thx = Text::Xatena->new(
	templates => {
		'SuperPre' => q[
			? if ($lang eq 'math') {
				<p class="{{= $class }} {{= "lang-$lang" }}">{{= $content }}</p>
			? } elsif ($lang) {
				<pre class="{{= $class }} {{= "lang-$lang" }}">{{= $content }}</pre>
			? } else {
				<pre class="{{= $class }}">{{= $content }}</pre>
			? }
		],
		'Section' => q[
			<section class="level-{{= $level }}">
				<h{{= $level + 2 }}>{{= $title }}</h{{= $level + 2 }}>
				{{= $content }}
			</section>
		],
		'Blockquote' => q[
			<figure class="quote">
				<blockquote {{ if ($cite) { }}cite="{{= $cite }}"{{ } }}>
					{{= $content }}
				</blockquote>
				{{ if ($title) { }}
				<figcaption>
					<cite>{{= $title }}</cite>
				</figcaption>
				{{ } }}
			</figure>
		],
		'SeeMore' => q[
			<!-- seemore -->
			<section class="seemore">
				{{= $content }}
			</section>
			<!-- /seemore -->
		]
	},
);

sub format {
	my ($class, $entry) = @_;
	my $inline = Nogag::Formatter::Hatena::Inline->new(
		ua	  => $ua,
		cache => Cache::FileCache->new,
		entry => $entry,
	);
	$thx->format($entry->body,
		inline => $inline
	);
}

package
	Nogag::Formatter::Hatena::Inline;

use Text::Xatena::Inline::Aggressive -Base;
use Log::Minimal;

no warnings 'redefine';
sub match ($$) { ## no critic
	my ($regexp, $block) = @_;
	my $pkg = caller(0);
	unshift @{ $pkg->inlines }, { regexp => $regexp, block => $block };
}

use URI::Escape;
use Amazon::PAApi5::Signature;
use Amazon::PAApi5::Payload;
use HTTP::Request::Common;
use LWP::UserAgent;
use XML::LibXML;
use Text::Xslate qw(mark_raw);
use JSON::XS;

use Nogag::Config;

my $xslate = Text::Xslate->new(
	syntax	 => 'TTerse',
);

sub render ($$) {
	my $str = $xslate->render_string(shift, shift);
	$str =~ s/\s+/ /g;
	$str;
}

use Data::OpenGraph;
use HTML::Microdata;
sub metadata_of ($) {
	my ($uri) = @_;

	my $res = $ua->get($uri);

	my $ret = {};

	my $og = Data::OpenGraph->parse_string($res->decoded_content);
	$ret->{title}		= $og->property('title');
	$ret->{image}		= $og->property('image');
	$ret->{description} = $og->property('description');

	my $microdata = HTML::Microdata->extract($res->decoded_content, base => $uri);
	my $item = $microdata->items->[0];
	if ($item) {
		$ret->{title}		= $item->{properties}->{name}->[0];
		$ret->{image}		= $item->{properties}->{image}->[0];
		$ret->{description} = $item->{properties}->{description}->[0];
	}

	if (!$ret->{title}) {
		($ret->{title}) = ($res->decoded_content =~ qr|<title[^>]*>([^<]*)</title>|i);
	}
	if (!$ret->{description}) {
		my ($description) = ($res->decoded_content =~ qr|<meta([^>]+name=['"]description['"][^>]*)>|i);
		($ret->{description}) = ($description =~ qr|content=['"](.+?)['"]|);
	}

	$ret;
}

match qr{\[?f:id:([^:]+):(\d+)([jpeg]):image\]?} => sub {
	my ($self, $user, $id, $type) = @_;

	render(q{
		<span itemscope itemtype="http://schema.org/Photograph">
			<a href="[% link %]" class="hatena-fotolife" itemprop="url"><img src="[% image %]" alt="photo" class="hatena-fotolife" itemprop="image"/></a>
		</span>
	}, {
		link  => $self->{entry}->path('/'),
		image => sprintf("http://cdn-ak.f.st-hatena.com/images/fotolife/%s/%s/%s/%s.%s", substr($user, 0, 1), $user, substr($id, 0, 8), $id, {
			j => 'jpg',
			p => 'png',
			g => 'gif',
		}->{$type} || 'jpg'),
	});
};


match qr{\[?asin:([^:]+):detail\]?(\s*[.\d]+)?}=> sub {
	my ($self, $asin, $rating) = @_;

	$asin = uc $asin;
	my $key = "ASIN:$asin";

	my $data = $self->cache->get($key);
	if (not defined $data) {
		infof("REQUESTING: %s", $key);

		my $payload = Amazon::PAApi5::Payload->new(
			config->param("amazon_tag"),
			'www.amazon.co.jp',
		)->to_json({
			Operation => 'GetItems',
			ItemIds => [$asin],
			Resources   => [qw/
				ItemInfo.Title
				ItemInfo.ByLineInfo
				Images.Primary.Large
			/],
		});
		 
		my $sig = Amazon::PAApi5::Signature->new(
			config->param("amazon_pa_api_access_key"),
			config->param("amazon_pa_api_secret_key"),
			$payload,
			{
				resource_path => '/paapi5/getitems',
				operation     => 'GetItems',
				host          => 'webservices.amazon.co.jp',
				region        => 'us-west-2',
			},
		);

		my $req = POST $sig->req_url, $sig->headers, Content => $sig->payload;
		my $res = $ua->request($req);
		use Data::Dumper;
		warn Dumper $res ;
		infof("RESPONSE FROM PA-API %s", $res);
		my $json = decode_json $res->decoded_content;

		my $item = $json->{ItemsResult}->{Items}->[0];

		$data = {
			author => $item->{ItemInfo}->{ByLineInfo}->{Contributors}->[0]->{Name} || $item->{ItemInfo}->{ByLineInfo}->{Brand}->{DisplayValue},
			title  => $item->{ItemInfo}->{Title}->{DisplayValue},
			image  => $item->{Images}->{Primary}->{Large}->{URL},
			link   => $item->{DetailPageURL},
		};

		$self->cache->set($key => $data, '1 month');
		sleep 1;
	}

	render(q{
		</p>
		<figure class="amazon" itemscope itemtype="http://schema.org/Review">
			<div class="image">
				<a href="[% link %]"><img src="[% image %]" alt="[% title %] - [% author %]" itemprop="image"/></a>
			</div>
			<figcaption class="detail">
				<p class="title" itemprop="itemReviewed" itemscope itemtype="http://schema.org/Product">
					<a href="[% link %]" itemprop="url"><span itemprop="name">[% title %]</span></a>
					<span itemprop="review" itemscope itemtype="http://schema.org/Review">
						<span itemprop="author" itemscope itemtype="https://schema.org/Person">
						<span itemprop="name">cho45</span>
						</span>
					</span>
				</p>
				<p class="author">[% author %]</p>
				<div class="rating" data-rating="[% rating %]" itemprop="reviewRating" itemscope itemtype="http://schema.org/Rating">
					&#9733;
					<meta itemprop="worstRating" content="1.0"/>
					<span itemprop="ratingValue">[% rating %]</span>
					/
					<span itemprop="bestRating">5.0</span>
				</div>
				<span itemprop="author" itemscope itemtype="https://schema.org/Person" style="display: none">
					<a href="http://www.lowreal.net/" itemprop="url">
						<span itemprop="name">cho45</span>
					</a>
				</span>
			</figcaption>
		</figure>
		<p>
	}, {
		%$data,
		rating => sprintf("%.1f", $rating || 3),
	});
};

match qr{figure:(https?://\S+)}=> sub {
	my ($self, $http) = @_;
	my $res = metadata_of($http);

	render(q{
		</p>
		<figure class="http" itemscope itemtype="http://schema.org/WebPage">
			<div class="image">
				<a href="[% link %]"><img src="[% image %]" alt="[% title %]" itemprop="image"/></a>
			</div>
			<figcaption class="detail">
				<p class="title">
					<a href="[% link %]" itemprop="url"><span itemprop="name">[% title %]</span></a>
				</p>
				<p class="description" itemprop="description">[% description %]</p>
			</figcaption>
		</figure>
		<p>
	}, +{
		%$res,
		link => $http,
	});
};

1;
__END__
