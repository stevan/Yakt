#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::System::Mailbox;
use Acktor::Props;

use Acktor::System::Timers;
use Acktor::System::IO;

use Acktor::System::Actors::Root;

class Acktor::System {
    use Acktor::Logging;

    use Time::HiRes qw[ time ];

    field $root;
    field $root_props;

    field %lookup;

    field @mailboxes;
    field $timers;
    field $io;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
        $timers = Acktor::System::Timers->new;
        $io     = Acktor::System::IO->new;
    }

    method io { $io }

    method schedule_timer (%options) {
        my $timeout  = $options{after};
        my $callback = $options{callback};

        $logger->log( DEBUG, "schedule( $timeout, $callback )" ) if DEBUG;

        my $timer = Acktor::System::Timers::Timer->new(
            timeout  => $timeout,
            callback => $callback,
        );

        $timers->schedule_timer($timer);

        return $timer;
    }

    method spawn_actor ($props, $parent=undef) {
        $logger->log( INTERNALS, "spawn($props)" ) if INTERNALS;
        my $mailbox = Acktor::System::Mailbox->new( props => $props, system => $self, parent => $parent );
        $lookup{ $mailbox->ref->pid } = $mailbox;
        if (my $alias = $mailbox->props->alias ) {
            $lookup{ $alias } = $mailbox;
        }
        push @mailboxes => $mailbox;
        return $mailbox->ref;
    }

    method despawn_actor ($ref) {
        $logger->log( INTERNALS, "despawn($ref) for ".$ref->context->props->class ."[".$ref->pid."]" ) if INTERNALS;
        if (my $mailbox = $lookup{ $ref->pid }) {
            $lookup{ $ref->pid } = $lookup{ '//sys/dead_letters' };
            if (my $alias = $mailbox->props->alias ) {
                delete $lookup{ $alias };
            }
            $mailbox->stop;
        }
        else {
            $logger->log( ERROR, "ACTOR NOT FOUND: $ref" ) if ERROR;
        }
    }

    method enqueue_message ($to, $message) {
        $logger->log( INTERNALS, "enqueue_message to($to) message($message)" ) if INTERNALS;
        if (my $mailbox = $lookup{ $to->pid }) {
            $mailbox->enqueue_message( $message );
        }
        else {
            $logger->log( ERROR, "ACTOR NOT FOUND: $to FOR MESSAGE: $message" ) if ERROR;
        }
    }

    method init ($init) {
        $root_props = Acktor::Props->new(
            class => 'Acktor::System::Actors::Root',
            alias => '//',
            args  => { init => $init }
        );
        $self;
    }

    method run_mailboxes {
        my @to_run = grep $_->to_be_run, @mailboxes;

        if (@to_run) {
            $logger->log( DEBUG, "... found (".scalar(@to_run).") mailbox(s) to run" ) if DEBUG;
            # run all the mailboxes ...
            my @unhandled = map $_->tick, @to_run;

            # handle any unhandled messages
            if (@unhandled) {
                $logger->log(WARN, "Got (".(scalar @unhandled).") dead letters ...") if WARN;
                $lookup{ '//sys/dead_letters' }->enqueue_message($_) foreach @unhandled;
            }

            # remove the stopped ones
            @mailboxes = grep !$_->is_stopped, @mailboxes;
        }
        else {
            $logger->log( DEBUG, "... nothing to run" ) if DEBUG;
        }
    }

    method tick {
        state $TICK = 0;
        my $t = sprintf '(%08d)' => $TICK;
        $logger->header('begin:tick', $t) if DEBUG;

        # timers
        $timers->tick;
        # mailboxes
        $self->run_mailboxes;
        # watchers
        $io->tick( $timers->should_wait );

        $logger->header('end:tick', $t) if DEBUG;
        $TICK++;
    }

    method loop_until_done {
        $logger->line('begin:loop') if DEBUG;

        $logger->log(DEBUG, 'Creating root actor ... ') if DEBUG;
        $root = $self->spawn_actor( $root_props );

        my $start = time();
        my $ticks = 0;
        my $total = 0;

        while (1) {
            $ticks++;

            # tick ...
            my $start_tick = time();
            $self->tick;
            my $end_tick = time() - $start_tick;
            $total += $end_tick;
            my $elapsed = time() - $start;

            $logger->bubble(
                'System Stats',
                [
                    (sprintf '%12s : %.09f' => 'current tick', $end_tick),
                    (sprintf '%12s : %.09f' => 'average tick', $total / $ticks),
                    (sprintf '%12s : %.09f' => 'total user',   $total),
                    (sprintf '%12s : %.09f' => 'total system', $elapsed - $total),
                    (sprintf '%12s : %.09f' => 'elapsed',      $elapsed),
                ]
            ) if DEBUG;

            $logger->bubble(
                'Actor Tree',
                [ $self->print_actor_tree($root) ]
            ) if DEBUG;

            # if we have timers or watchers, then loop again ...
            next if $timers->has_active_timers
                 || $io->has_active_selectors;

            # if no timers, see if we have active children ...
            if ( my $usr = $lookup{ '//usr' } ) {
                if ( $usr->is_alive && !$usr->children && !(grep $_->to_be_run, @mailboxes) ) {
                    $logger->alert('... nothing more to do, getting ready to stop!') if DEBUG;
                    # and if not, then we can shutdown ...
                    $usr->context->stop;
                }
            }

            # only after shutdown will we have no more
            # mailboxes, at which point we exit the loop
            last unless @mailboxes;
        }
        $logger->line('end:loop') if DEBUG;
    }

    method print_actor_tree ($ref, $indent='') {
        my @out;
        if (refaddr $ref == refaddr $root && $ref->context->is_stopped) {
            push @out => 'No Active Actors';
        } else {
            push @out => sprintf '%s<%s>[%03d]' => $indent, $ref->context->props->class, $ref->pid;;
        }
        $indent .= '    ';
        foreach my $child ( $ref->context->children ) {
            push @out => $self->print_actor_tree( $child, $indent );
        }
        return @out;
    }

}


