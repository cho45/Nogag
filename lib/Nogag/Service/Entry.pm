package Nogag::Service::Entry;

use utf8;
use strict;
use warnings;

use parent qw(Nogag::Service);

use Nogag::Time;
use Time::Seconds;
use Nogag::Model::Entry;
use Log::Minimal;

sub retrieve_entry_by_id {
	my ($self, $id) = @_;
	my $entry = $self->dbh->select(q{
		SELECT * FROM entries
		WHERE id = :id
	}, {
		id => $id
	})->[0];
	$entry ? Nogag::Model::Entry->bless($entry) : undef;
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
	$params{status} ||= 'public';
	# always set GMT on DB
	$params{publish_at} = defined $params{publish_at} ? gmtime($params{publish_at}->epoch) : undef;
	if ($params{publish_at} && $params{publish_at} > gmtime) {
		$params{status} = 'scheduled';
	}

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
				`modified_at`,
				`publish_at`,
				`status`
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
				:modified_at,
				:publish_at,
				:status
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
	$entry->{status} = $params{status} || 'public';
	# always set GMT on DB
	$entry->{publish_at} = defined $params{publish_at} ? gmtime($params{publish_at}->epoch) : undef;
	if ($params{publish_at} && $params{publish_at} > gmtime) {
		$params{status} = 'scheduled';
	}

	$self->dbh->update(q{
		UPDATE entries
		SET
			title = :title,
			body = :body,
			modified_at = :modified_at,
			publish_at = :publish_at,
			formatted_body = :formatted_body,
			status = :status
		WHERE
			id = :id
	}, {
		id             => $entry->{id},
		title          => $entry->{title},
		body           => $entry->{body},
		formatted_body => $entry->{formatted_body},
		publish_at     => $entry->{publish_at},
		modified_at    => gmtime.q(),
		status         => $entry->{status},
	});

	$self->retrieve_entry_by_id($entry->id);
}

sub format_body {
	my ($self, $entry) = @_;
	my $formatter = "Nogag::Formatter::" . ($entry->format || 'Hatena');
	$formatter->use or die $@;
	my $formatted_body = $formatter->format($entry);
	$formatted_body = Nogag::Utils->postprocess($formatted_body);
}

sub publish_scheduled_entries {
	my ($self) = @_;

	my $now = gmtime;

	my $entries = $self->dbh->select(q{
		SELECT * FROM entries
		WHERE status = 'scheduled' AND publish_at < :now
	}, {
		now => $now
	});

	Nogag::Model::Entry->bless($_) for @$entries;

	infof("publish_scheduled_entries %s -> count %d",$now, scalar @$entries);

	$self->dbh->update(q{
		UPDATE entries
		SET status = 'public'
		WHERE id IN (:ids)
	}, {
		ids => [ map { $_->id } @$entries ]
	});

	for my $entry (@$entries) {

		infof("published %s (%d). append worker", $entry->path, $entry->id);
		$self->r->work_job('Nogag::Worker::PostEntry', {
			entry => $entry,
			invalidate_target => "".$entry->id,
		}, uniqkey => 'postentry-' . $entry->id);
	}

	$entries;
}


1;
__END__
