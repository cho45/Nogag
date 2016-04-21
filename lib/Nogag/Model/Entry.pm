package Nogag::Model::Entry;

use utf8;
use strict;
use warnings;

use Nogag::Time;
use HTML::Trim;
use Text::Overflow qw(ellipsis);

sub bless {
	my ($class, $hash) = @_;
	bless $hash, $class;
}

sub id             { $_[0]->{id} }
sub body           { $_[0]->{body} }
sub formatted_body {
	my ($self, $expand) = @_;
	if ($expand) {
		$self->{formatted_body}
	} else {
		my $path = $self->path('/');
		my $title = $self->title || '';

		my $formatted_body = $self->{formatted_body};
		$formatted_body =~ s{
			<!-- \s seemore \s -->
			.+?
			<!-- \s /seemore \s -->
		}{<a href="$path" class="seemore">&raquo; $title の続きを読む</a>}xs;
		$formatted_body;
	}
}
sub format         { $_[0]->{format} }

sub formatted_body_text {
	my ($self) = @_;
	my $text = $self->formatted_body;
	$text =~ s{<[^>]+?>}{}g;
	$text;
}

sub path {
	my ($self, $prefix) = @_;
	$prefix ||= '';
	$prefix . $self->{path};
}

sub date {
	$_[0]->{__date} //= Nogag::Time->from_db($_[0]->{date});
}

sub created_at {
	$_[0]->{__created_at} //= Nogag::Time->from_db($_[0]->{created_at});
}

sub modified_at {
	$_[0]->{__modified_at} //= Nogag::Time->from_db($_[0]->{modified_at});
}

sub title_tags {
	my ($self) = @_;
	$self->{title_tags} ||= do {
		my $title = $self->{title};
		my $tags = [];
		$title =~ s{\s*\[([^]]+)\]\s*}{
			push @$tags, $1;
			'';
		}eg;

		[ $title, $tags ]
	};
}

sub title {
	my ($self) = @_;
	$self->title_tags->[0];
}

sub raw_title {
	my ($self) = @_;
	$self->{title}
}

sub title_for_permalink {
	my ($self) = @_;
	my $title;
	if ($self->raw_title) {
		$title = $self->title;
		if (@{ $self->tags }) {
			$title .= ' | ' . join(' | ', @{ $self->tags });
		}
	} else {
		$title = $self->summary_html(50);
	}

	unless ($self->title) {
		$title .= $self->date->strftime(' | %a, %b %e. %Y');
	}

	$title =~ s/<[^>]+>//g;
	$title =~ s{^\s+|\s+$}{}g;
	$title;
}

sub tags {
	my ($self) = @_;
	$self->title_tags->[1];
}

sub has_tag {
	my ($self, $name) = @_;
	for my $tag (@{ $self->tags }) {
		return 1 if $name eq $tag;
	}
	0;
}

sub image {
	my ($self) = @_;
	my ($img)  = ($self->formatted_body =~ m{(<img[^>]+>)}) or return undef;
	my ($src)  = ($img =~ m{src=['"]([^'">]+)['"]}) or return undef;
	$src;
}

sub summary {
	my ($self, $length) = @_;
	$length ||= 50;
	my $key = "_summary_$length";
	$self->{$key} //= do {
		my $body = $self->formatted_body;
		$body =~ s{<(style|script)[^>]*>[^<]*</(style|script)>}{};
		$body =~ s/<[^>]+>//g;
		$body =~ s{^\s+|\s+$}{}g;
		ellipsis($body, $length);
	}
}

sub summary_html {
	my ($self, $length) = @_;
	$length ||= 50;
	my $key = "_summary_html_$length";
	$self->{$key} //= do {
		HTML::Trim::vtrim($self->formatted_body, $length, '…');
	};
}

1;
__END__
