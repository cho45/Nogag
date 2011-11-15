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
sub title          { $_[0]->{title} }
sub body           { $_[0]->{body} }
sub formatted_body { $_[0]->{formatted_body} }
sub path           { $_[0]->{path} }
sub format         { $_[0]->{format} }

sub sort_time {
	Nogag::Time->from_db($_[0]->{sort_time});
}

sub created_at {
	Nogag::Time->from_db($_[0]->{created_at});
}

sub modified_at {
	Nogag::Time->from_db($_[0]->{modified_at});
}

sub tags {
	my ($self) = @_;
	[ $self->title =~ /\[([^]]+)\]/g ];
}

1;
__END__
