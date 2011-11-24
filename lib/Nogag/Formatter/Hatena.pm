package Nogag::Formatter::Hatena;

use utf8;
use strict;
use warnings;

use Text::Xatena;
use Cache::MemoryCache;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->timeout(5);

my $thx = Text::Xatena->new(
    templates => {
        'Section' => q[
            <section class="level-{{= $level }}">
                <h1>{{= $title }}</h1>
                {{= $content }}
            </section>
        ],
        'Blockquote' => q[
            <figure class="quote">
            ? if ($cite) {
                <blockquote cite="{{= $cite }}">
                    {{= $content }}
                </blockquote>
                <figcaption>
                    <cite>{{= $title }}</cite>
                </figcaption>
            ? } else {
                <blockquote>
                    {{= $content }}
                </blockquote>
            ? }
            </figure>
        ],
    },
);

sub format {
    my ($class, $entry) = @_;
    my $inline = Nogag::Formatter::Hatena::Inline->new(
        ua    => $ua,
        cache => Cache::MemoryCache->new,
        entry => $entry,
    );
    $thx->format($entry->body,
        inline => $inline
    );
}

package
    Nogag::Formatter::Hatena::Inline;

use Text::Xatena::Inline::Aggressive -Base;

use URI::Escape;
use URI::Amazon::APA;
use LWP::UserAgent;
use XML::LibXML;
use Text::Xslate qw(mark_raw);

use Nogag::Config;

my $xslate = Text::Xslate->new(
    syntax   => 'TTerse',
);

sub render ($$) {
    my $str = $xslate->render_string(shift, shift);
    $str =~ s/\s+/ /g;
    $str;
}

match qr{\[?f:id:([^:]+):(\d+)([jpeg]):image\]?} => sub {
    my ($self, $user, $id, $type) = @_;

    render(q{
        <a href="[% link %]" class="hatena-fotolife"><img src="[% image %]" alt="photo" class="hatena-fotolife"/></a>
    }, {
        link  => $self->{entry}->path('/'),
        image => sprintf("http://cdn-ak.f.st-hatena.com/images/fotolife/%s/%s/%s/%s.jpg", substr($user, 0, 1), $user, substr($id, 0, 8), $id),
    });
};


match qr{\[?asin:([^:]+):detail\]?}=> sub {
    my ($self, $asin) = @_;

    my $uri = URI::Amazon::APA->new('http://webservices.amazon.co.jp/onca/xml');
    $uri->query_form(
        Service       => 'AWSECommerceService',
        Operation     => 'ItemLookup',
        IdType        => 'ASIN',
        ItemId        => $asin,
        AssociateTag  => config->param('amazon_tag'),
        Condition     => 'All',
        ResponseGroup => 'ItemAttributes,Images',
    );

    $uri->sign(
        key    => config->param('amazon_key'),
        secret => config->param('amazon_secret'),
    );

    my $ua = LWP::UserAgent->new;
    my $res  = $ua->get($uri);
    $res->is_success or die $res->content;

    my $doc = XML::LibXML->load_xml( string => $res->content );
    my $xpc = XML::LibXML::XPathContext->new($doc);
    $xpc->registerNs('a', 'http://webservices.amazon.com/AWSECommerceService/2010-09-01');
    my $node = $xpc->findnodes('/a:ItemLookupResponse/a:Items/a:Item')->[0];

    render(q{
        </p>
        <figure class="amazon">
            <div class="image">
                <a href="[% link %]"><img src="[% image %]" alt="[% title %] - [% author %]"/></a>
            </div>
            <figcaption class="detail">
                <p class="title"><a href="[% link %]">[% title %]</a></p>
                <p class="author">[% author %]</p>
            </figcaption>
        </figure>
        <p>
    }, {
        author => $xpc->findvalue('a:ItemAttributes/a:Author', $node),
        title  => $xpc->findvalue('a:ItemAttributes/a:Title', $node),
        image  => $xpc->findvalue('a:MediumImage/a:URL', $node),
        link   => $xpc->findvalue('a:DetailPageURL', $node),
    });
};

1;
__END__
