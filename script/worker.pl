#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use constant MAX_WORKER => 2;
use constant MAX_REQUEST_PER_CHILD => 100;
use constant INTERVAL => $ENV{INTERVAL} || 5;
use constant NAMESPACE => 'Nogag::Worker';


use TheSchwartz;
use Log::Minimal;
use Module::Find ();
use DBIx::DisconnectAll;
use Parallel::Prefork;

use Nogag;
Nogag->setup_schema;

my $databases = [ { dsn => 'dbi:SQLite:' . config->param('worker_db'), user => '', pass => '' } ];

my $pm = Parallel::Prefork->new({
    max_workers  => MAX_WORKER,
    trap_signals => {
        TERM => 'TERM',
        HUP  => 'INT',
        INT  => 'INT',
        USR1 => undef,
    }
});

infof("[%d] Worker starting...", $$);
$0 = "worker master";

while ($pm->signal_received !~ 'TERM|INT|HUP') {
    $pm->start(sub {
        infof("[%d] New worker started", $$);

        my $run = 1;
        my $count = 0;

        $SIG{INT} = $SIG{HUP} = sub {
            infof("[%d] Signal received will teminate", $$);
            $run = 0;
        };
        $SIG{TERM} = sub {
            infof("[%d] SIGTERM received. Exit immediately", $$);
            exit 1;
        };

        sleep rand() * INTERVAL;

        my $client = TheSchwartz->new(
            databases => $databases,
        );

        my $workers = [ Module::Find::useall(NAMESPACE) ];
        for my $worker (@$workers) {
            infof('[%d] Enable working for %s', $$, $worker);
            $client->can_do($worker);
        }

        while ($run && ($count < MAX_REQUEST_PER_CHILD)) {
            if (getppid == 1) { infof("I'm zombie..."); exit 1; }
            $0 = sprintf("worker slave(%d)", $count);

            my $job = $client->find_job_for_workers;
            if (!$job && @{ $client->{current_abilities} } < @{ $client->{all_abilities} }) {
                $client->restore_full_abilities;
                $job = $client->find_job_for_workers;
            }

            if ($job) {
                infof('[%d] job:%d Work %s', $$, $job->jobid, $job->funcname);
                $0 = sprintf("worker slave(%d) >%s %s", $count, $job->jobid, $job->funcname);
                $client->work_once($job);
                $count++;

                my $exit_status = $job->exit_status;
                if (!$exit_status) {
                    my $done = defined $exit_status ? 'Success' : 'Done(Status Unknown)';
                    infof('[%d] job:%d %s %s', $$, $job->jobid, $done, $job->funcname);
                } else {
                    critf("[%d] job:%d %s", $$, $job->jobid, join("\n",  $job->failure_log));
                    critf('[%d] job:%d Failed %s', $$, $job->jobid, $job->funcname);
                }

                # Disconnect all db handles for MHA
                dbi_disconnect_all();
            } else {
                # Disconnect all db handles for MHA
                dbi_disconnect_all();
                sleep INTERVAL;
            }
        }

        infof("[%d] Worker has finished (worked:%d)", $$, $count);
    });
}

infof("[%d] Worker exiting...", $$);
$0 = "worker master: exiting...";
$pm->signal_all_children('INT');
$pm->signal_all_children('INT');
$pm->wait_all_children();
infof("[%d] Worker exit", $$);
