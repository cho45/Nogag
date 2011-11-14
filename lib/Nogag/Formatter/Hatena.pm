package Nogag::Formatter::Hatena;

use utf8;
use strict;
use warnings;

use Text::Xatena;
use Cache::MemoryCache;

sub format {
	my ($class, $string) = @_;
	Text::Xatena->new->format($string,
		inline => Nogag::Formatter::Hatena::Inline->new(cache => Cache::MemoryCache->new)
	);
}

package
	Nogag::Formatter::Hatena::Inline;

use Text::Xatena::Inline::Base -Base;
use parent qw(Text::Xatena::Inline::Aggressive);

match qr{f:id:([^:]+):(\d+)([jpeg]):image} => sub {
	my ($self, $user, $id, $type) = @_;

	my $linkto = "http://f.hatena.ne.jp/$user/$id";
	my $image  = sprintf("http://cdn-ak.f.st-hatena.com/images/fotolife/%s/%s/%s/%s.jpg", substr($user, 0, 1), $user, substr($id, 0, 8), $id);
	qq{<a href="$linkto" class="hatena-fotolife"><img src="$image" alt="photo" class="hatena-fotolife"></a>}
};

1;
__END__
