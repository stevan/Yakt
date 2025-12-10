#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Mailbox;

use Yakt::System::Signals;

use Yakt::System::Timers;
use Yakt::System::IO;

use Yakt::System::Actors::Root;

class Yakt::System {
    use Yakt::Logging;

    use Time::HiRes qw[ time ];

    field $root;
    field $root_props;

    field %lookup;

    field @mailboxes;
    field $timers;
    field $io;

    field $logger;

    field $shutting_down = false;
    field $pid_seq = 0;

    ADJUST {
        $logger = Yakt::Logging->logger(__PACKAGE__) if LOG_LEVEL;
        $timers = Yakt::System::Timers->new;
        $io     = Yakt::System::IO->new;
    }

    method io { $io }

    method schedule_timer (%options) {
        my $timeout  = $options{after};
        my $callback = $options{callback};

        $logger->log( DEBUG, "schedule( $timeout, $callback )" ) if DEBUG;

        my $timer = Yakt::System::Timers::Timer->new(
            timeout  => $timeout,
            callback => $callback,
        );

        $timers->schedule_timer($timer);

        return $timer;
    }

    method spawn_actor ($props, $parent=undef) {
        $logger->log( INTERNALS, "spawn($props)" ) if INTERNALS;
        my $mailbox = Yakt::System::Mailbox->new(
            props  => $props,
            system => $self,
            parent => $parent,
            pid    => ++$pid_seq,
        );
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
            delete $lookup{ $ref->pid };
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
            $lookup{ '//sys/dead_letters' }->enqueue_message(
                Yakt::System::Actors::DeadLetterQueue::DeadLetter->new(
                    to      => $to,
                    message => $message
                )
            );
        }
    }

    method shutdown {
        if ($shutting_down) {
            $logger->log( DEBUG, "Got Shutdown message ... already shutting down, please be patient" ) if DEBUG;
        }
        else {
            $logger->log( DEBUG, "Got Shutdown message ..." ) if DEBUG;
            if ( my $usr = $lookup{ '//usr' } ) {
                $logger->log( DEBUG, "... found $usr to stop" ) if DEBUG;
                $usr->context->stop;
                $shutting_down = true;
            } else {
                $logger->log( ERROR, "... no User process found!" ) if ERROR;
                $root->context->stop;
            }
        }
    }

    method init ($init) {
        $root_props = Yakt::Props->new(
            class => 'Yakt::System::Actors::Root',
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
            $_->prepare foreach @to_run;
            my @unhandled = map $_->tick, @to_run;
            $_->finish foreach @to_run;

            # handle any unhandled messages
            if (@unhandled) {
                $logger->log(INTERNALS, "Got (".(scalar @unhandled).") dead letters ") if INTERNALS;
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
        $logger->header('begin:tick') if DEBUG;

        # timers
        $timers->tick;
        # mailboxes
        $self->run_mailboxes;
        # watchers
        $io->tick( $timers->should_wait );

        $logger->header('end:tick') if DEBUG;
    }

    method loop_until_done {
        $logger->line('begin:loop') if DEBUG;

        $logger->log(DEBUG, 'Creating root actor ... ') if DEBUG;
        $root = $self->spawn_actor( $root_props );

        while (1) {

            # tick ...
            $self->tick;

            $logger->bubble(
                'Actor Tree',
                [ $self->print_actor_tree($root) ]
            ) if DEBUG;

            # if we have timers or watchers, then loop again ...
            next if $timers->has_active_timers
                 || $io->has_active_selectors;

            # if any mailbox is in a transitional state, keep looping
            next if grep { $_->is_stopping || $_->is_restarting || $_->is_starting } @mailboxes;

            # if no timers, see if we have active children ...
            if ( my $usr = $lookup{ '//usr' } ) {
                #warn "Is user Alive: ".$usr->is_alive;
                #warn "User Children: ".scalar $usr->children;
                #warn "Mailboxes to run: ".join(', ' => grep $_->to_be_run, @mailboxes);
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


