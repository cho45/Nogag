use strict;
use warnings;
use lib lib => 't/lib' => glob 'modules/*/lib';

use File::Which;
use Data::Dumper;
use Path::Class;
use File::Temp;
use HTTP::Server::PSGI;
use HTTP::Request;
use LWP::UserAgent;
use URI;
use Encode;

use Test::More;
use Test::TCP;
use Test::HTML::Differences -color;


my $backend = Test::TCP->new(
	code => sub {
		my $port = shift;
		local $ENV{PORT} = $port;
		exec 'node', './script/postprocess-js-daemon.js';
	}
);
my $ua = LWP::UserAgent->new( max_redirect => 0 );

sub postprocess {
	my ($html) = @_;
	my $res = $ua->post(sprintf('http://127.0.0.1:%d/', $backend->port), Content => encode_utf8 $html);
	if ($res->is_success) {
		return $res->decoded_content;
	} else {
		critf("failed %p", $res);
		return $html;
	}
}

sub minify {
	my ($html) = @_;
	my $res = $ua->post(sprintf('http://127.0.0.1:%d/?minifyOnly=1', $backend->port), Content => encode_utf8 $html);
	if ($res->is_success) {
		return $res->decoded_content;
	} else {
		critf("failed %p", $res);
		return $html;
	}
}
is minify(q{
<article
	id="post-[% entry.created_at.epoch %]"
	class="[% entry.tags.join(' ') %] [% IF is_first %]first[% END %]"
	data-id="[% entry.id %]"
	[% UNLESS permalink %]itemprop="blogPosts"[% END %]
	[% UNLESS permalink %]itemscope[% END %]
	[% UNLESS permalink %]itemtype="http://schema.org/BlogPosting"[% END %]
	>
</article>
}), q{<article class="[% entry.tags.join(' ') %] [% IF is_first %]first[% END %]" data-id="[% entry.id %]" id="post-[% entry.created_at.epoch %]" [% UNLESS permalink %]itemprop=blogPosts [% END %][% UNLESS permalink %]itemscope [% END %][% UNLESS permalink %]itemtype=http://schema.org/BlogPosting[% END %]> </article>};

eq_or_diff_html(postprocess(q{
	<img src="https://lh3.googleusercontent.com/-gFvsrqiOy_U/VxV-QUgXd0I/AAAAAAAAePQ/UN4Am17BEkciBCLf9xwI5tFQai7vKfZvwCLcB/s2048/2016-04-19%2B09.25.31.png" alt="photo" itemprop="image"/>
}), q{
	<img width="752" height="425" src="https://lh3.googleusercontent.com/-gFvsrqiOy_U/VxV-QUgXd0I/AAAAAAAAePQ/UN4Am17BEkciBCLf9xwI5tFQai7vKfZvwCLcB/s2048/2016-04-19%2B09.25.31.png" alt="photo" itemprop="image"/>
});


eq_or_diff_html(postprocess(q{
	<img src="https://lh6.googleusercontent.com/-s1ubWY8ZX7E/VLZXq1E8WXI/AAAAAAAAXaM/5-4XRs70R44/s900/2015-01-14%2B20.43.41.png" alt="photo" itemprop="image"/>
}), q{
	<img width="2048" height="1345" src="https://lh6.googleusercontent.com/-s1ubWY8ZX7E/VLZXq1E8WXI/AAAAAAAAXaM/5-4XRs70R44/s2048/2015-01-14%2B20.43.41.png" alt="photo" itemprop="image"/>
});

eq_or_diff_html(postprocess(q{
	<img src="http://lh6.ggpht.com/-RCha43JvQuk/UOEDmNMYEpI/AAAAAAAAHX8/bsj8fUVpeig/s900/IMG_0226-2048.jpg" alt="photo" itemprop="image"/>
}), q{
	<img width="2048" height="1365" src="https://lh6.ggpht.com/-RCha43JvQuk/UOEDmNMYEpI/AAAAAAAAHX8/bsj8fUVpeig/s2048/IMG_0226-2048.jpg" alt="photo" itemprop="image"/>
});

eq_or_diff_html(postprocess(q{
	<img alt="photo" itemprop="image" src="http://lh6.ggpht.com/-RCha43JvQuk/UOEDmNMYEpI/AAAAAAAAHX8/bsj8fUVpeig/s900/IMG_0226-2048.jpg"/>
}), q{
	<img width="2048" height="1365" alt="photo" itemprop="image" src="https://lh6.ggpht.com/-RCha43JvQuk/UOEDmNMYEpI/AAAAAAAAHX8/bsj8fUVpeig/s2048/IMG_0226-2048.jpg"/>
});

eq_or_diff_html(postprocess(q{
	<img alt=photo itemprop=image src=http://lh6.ggpht.com/-RCha43JvQuk/UOEDmNMYEpI/AAAAAAAAHX8/bsj8fUVpeig/s900/IMG_0226-2048.jpg>
}), q{
	<img width="2048" height="1365" alt="photo" itemprop="image" src="https://lh6.ggpht.com/-RCha43JvQuk/UOEDmNMYEpI/AAAAAAAAHX8/bsj8fUVpeig/s2048/IMG_0226-2048.jpg"/>
});

eq_or_diff_html(postprocess(q{
	<img src="http://cdn-ak.f.st-hatena.com/images/fotolife/c/cho45/20101231/20101231142133.jpg" alt="photo" class="hatena-fotolife" itemprop="image"/>
}), q{
	<img width="900" height="600" src="https://cdn-ak.f.st-hatena.com/images/fotolife/c/cho45/20101231/20101231142133.jpg" alt="photo" class="hatena-fotolife" itemprop="image"/>
});

eq_or_diff_html(postprocess(q{
	<img alt=photo class=hatena-fotolife itemprop=image src=http://cdn-ak.f.st-hatena.com/images/fotolife/c/cho45/20101231/20101231131457.jpg>
}), q{
	<img width="900" height="600" alt=photo class=hatena-fotolife itemprop=image src=https://cdn-ak.f.st-hatena.com/images/fotolife/c/cho45/20101231/20101231131457.jpg>
});

eq_or_diff_html(postprocess(q{
	<img src="http://ecx.images-amazon.com/images/I/51-btt0hQhL._SL160_.jpg" alt="amazon" itemprop="image">
}), q{
	<img width="114" height="160" src="https://images-na.ssl-images-amazon.com/images/I/51-btt0hQhL._SL160_.jpg" alt="amazon" itemprop="image">
});

eq_or_diff_html(postprocess(q{
	<iframe width="560" height="315" src="http://www.youtube.com/embed/MGt25mv4-2Q" frameborder="0" allowfullscreen></iframe>
}), q{
	<iframe width="560" height="315" src="https://www.youtube.com/embed/MGt25mv4-2Q" frameborder="0" allowfullscreen></iframe>
});

like postprocess(q{
	<script src="https://gist.github.com/cho45/4326cf94e22f8e921d0f.js"></script>
}), qr{\A<div class=gist-github-com-js>[\s\S]+</div>\z};

done_testing;
