package Nogag::Service::Entry;

use utf8;
use strict;
use warnings;

use parent qw(Nogag::Service);

use Nogag::Time;
use Time::Seconds;
use Nogag::Model::Entry;

sub retrieve_entry_by_id {
	my ($self, $id) = @_;
	my $entry = $self->dbh->select(q{
		SELECT * FROM entries
		WHERE id = :id
	}, {
		id => $id
	})->[0];
	Nogag::Model::Entry->bless($entry);
}

sub create_new_entry {
	my ($self, %params) = @_;

	my $date = localtime;
	my $now  = gmtime;

	$params{format} ||= 'Hatena';

	$params{path} ||= do {
		my $count = $self->dbh->select('SELECT count(*) FROM entries WHERE `date` = ?', { date => $date->strftime('%Y-%m-%d') })->[0]->{'count(*)'};
		my $path  = $date->strftime('%Y/%m/%d/') . ($count + 1);
	};

	$params{date} ||= $date->strftime('%Y-%m-%d');
	$params{created_at}  = $now;
	$params{modified_at} = $now;

	$params{formatted_body} = $self->format_body(Nogag::Model::Entry->bless({
		%params
	}));

	$self->dbh->update(q{
		INSERT INTO entries
			(
				`title`,
				`body`,
				`formatted_body`,
				`path`,
				`format`,
				`date`,
				`created_at`,
				`modified_at`
			)
			VALUES
			(
				:title,
				:body,
				:formatted_body,
				:path,
				:format,
				:date,
				:created_at,
				:modified_at
			)
	}, {
		%params
	});

	my $id = $self->dbh->sqlite_last_insert_rowid;
	$self->retrieve_entry_by_id($id);
}

sub update_entry {
	my ($self, $entry, %params) = @_;

	$entry->{title} = $params{title};
	$entry->{body} = $params{body};
	$entry->{formatted_body} = $self->format_body($entry);

	$self->dbh->update(q{
		UPDATE entries
		SET
			title = :title,
			body = :body,
			modified_at = :modified_at,
			formatted_body = :formatted_body
		WHERE
			id = :id
	}, {
		id             => $entry->{id},
		title          => $entry->{title},
		body           => $entry->{body},
		formatted_body => $entry->{formatted_body},
		modified_at    => gmtime.q(),
	});

	$entry;
}

sub format_body {
	my ($self, $entry) = @_;
	my $formatter = "Nogag::Formatter::" . ($entry->format || 'Hatena');
	$formatter->use or die $@;
	my $formatted_body = $formatter->format($entry);
	$formatted_body = Nogag::Utils->postprocess($formatted_body);
}


1;
__END__
