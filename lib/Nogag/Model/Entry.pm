package Nogag::Model::Entry;

use utf8;
use strict;
use warnings;

use Nogag::Time;

sub bless {
	my ($class, $hash) = @_;
	bless $hash, $class;
}

sub id             { $_[0]->{id} }
sub body           { $_[0]->{body} }
sub formatted_body { $_[0]->{formatted_body} }
sub path           { $_[0]->{path} }
sub format         { $_[0]->{format} }

sub date {
	Nogag::Time->from_db($_[0]->{date});
}

sub created_at {
	Nogag::Time->from_db($_[0]->{created_at});
}

sub modified_at {
	Nogag::Time->from_db($_[0]->{modified_at});
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

sub tags {
	my ($self) = @_;
	$self->title_tags->[1];
}

1;
__END__