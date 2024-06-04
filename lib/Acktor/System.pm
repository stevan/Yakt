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

    field $root;

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
        $logger->log( DEBUG, "spawn($props)" ) if DEBUG;
        my $mailbox = Acktor::System::Mailbox->new( props => $props, system => $self, parent => $parent );
        $lookup{ $mailbox->ref->pid } = $mailbox;
        if (my $alias = $mailbox->props->alias ) {
            $lookup{ $alias } = $mailbox;
        }
        push @mailboxes => $mailbox;
        return $mailbox->ref;
    }

    method despawn_actor ($ref) {
        $logger->log( DEBUG, "despawn($ref) for ".$ref->context->props->class ."[".$ref->pid."]" ) if DEBUG;
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
        $logger->log( DEBUG, "enqueue_message to($to) message($message)" ) if DEBUG;
        if (my $mailbox = $lookup{ $to->pid }) {
            $mailbox->enqueue_message( $message );
        }
        else {
            $logger->log( ERROR, "ACTOR NOT FOUND: $to FOR MESSAGE: $message" ) if ERROR;
        }
    }

    method init ($init) {
        $root = $self->spawn_actor(
            Acktor::Props->new(
                class => 'Acktor::System::Actors::Root',
                alias => '//',
                args  => { init => $init }
            )
        );
        $self;
    }

    method run_mailboxes {
        my @to_run = grep $_->to_be_run, @mailboxes;

        if (@to_run) {
            $logger->log( WARN, "... running (".scalar(@to_run).") mailboxe(s)" ) if WARN;
            # run all the mailboxes ...
            $_->tick foreach @to_run;
            # remove the stopped ones
            @mailboxes = grep !$_->is_stopped, @mailboxes;
        }
        else {
            $logger->log( WARN, "... nothing to run" ) if WARN;
        }
    }

    method tick {
        state $TICK = 0;
        $logger->header('begin:tick['.$TICK.']') if DEBUG;

        # timers
        $timers->tick;
        # mailboxes
        $self->run_mailboxes;
        # watchers
        $io->tick( $timers->should_wait );

        # ... check to see if we should wait
        #if (my $wait_for = $timers->should_wait) {
        #    $logger->log( WARN, "... waiting ($wait_for)" ) if WARN;
        #    $timers->wait( $wait_for );
        #}

        $logger->header('end:tick['.$TICK.']') if DEBUG;
        $TICK++;
    }

    method loop_until_done {
        $logger->line('begin:loop') if DEBUG;
        while (1) {
            # tick ...
            $self->tick;

            if (DEBUG) {
                $logger->line('Acktor Hierarchy') if DEBUG;
                $self->print_actor_tree($root);
            }

            # if we have timers or watchers, then loop again ...
            next if $timers->has_active_timers
                 || $io->has_active_selectors;

            # if no timers, see if we have active children ...
            if ( my $usr = $lookup{ '//usr' } ) {
                if ( $usr->is_alive && !$usr->children && !(grep $_->to_be_run, @mailboxes) ) {
                    $logger->alert('... nothing more to do, getting ready to stop!') if DEBUG;
                    # and if not, then we can shutdown ...
                    $root->context->stop;
                }
            }

            # only after shutdown will we have no more
            # mailboxes, at which point we exit the loop
            last unless @mailboxes;
        }
        $logger->line('end:loop') if DEBUG;
    }

    method print_actor_tree ($ref, $indent='') {
        if (refaddr $ref == refaddr $root && $ref->context->is_stopped) {
            $logger->log(DEBUG, 'No Active Actors' ) if DEBUG;
        } else {
            $logger->log(DEBUG, sprintf '%s<%s>[%03d]' => $indent, $ref->context->props->class, $ref->pid ) if DEBUG;
        }
        $indent .= '  ';
        foreach my $child ( $ref->context->children ) {
            $self->print_actor_tree( $child, $indent );
        }
    }

}


