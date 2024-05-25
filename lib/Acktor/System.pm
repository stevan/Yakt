#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Mailbox;
use Acktor::Props;
use Acktor::System::Timers;
use Acktor::System::Actors::Root;

class Acktor::System {
    use Acktor::Logging;

    field $root;

    field %lookup;
    field @mailboxes;

    field $timers;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
        $timers = Acktor::System::Timers->new;
    }


    method schedule_timer (%options) {
        my $timeout  = $options{after};
        my $callback = $options{callback};

        $logger->log( DEBUG, "schedule( $timeout, $callback )" ) if DEBUG;

        my $timer = Acktor::Timer->new(
            timeout  => $timeout,
            callback => $callback,
        );

        $timers->schedule_timer($timer);

        return $timer;
    }

    method spawn_actor ($props, $parent=undef) {
        $logger->log( DEBUG, "spawn($props)" ) if DEBUG;
        my $mailbox = Acktor::Mailbox->new( props => $props, system => $self, parent => $parent );
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

    method tick {
        state $TICK = 0;
        $logger->header('begin:tick['.$TICK.']') if DEBUG;

       if ($timers->has_timers) {
            $logger->line( "begin:timers" ) if DEBUG;
            $timers->tick;
            $logger->line( "end:timers" ) if DEBUG;
        }

        my @to_run = grep $_->to_be_run, @mailboxes;

        if (@to_run) {
            # run all the mailboxes ...
            $_->tick foreach @to_run;
            # remove the stopped ones
            @mailboxes = grep !$_->is_stopped, @mailboxes;
        }
        else {
            # otherwise check for timers ...
            $logger->log( WARN, "... nothing to run" ) if WARN;
            if (my $wait = $timers->should_wait) {
                $logger->log( WARN, "... waiting ($wait)" ) if WARN;
                $timers->sleep( $wait );
            }
        }

        $logger->header('end:tick['.$TICK.']') if DEBUG;
        $TICK++;
    }

    method loop_until_done {
        $logger->line('begin:loop') if DEBUG;
        while (1) {
            $self->tick;

            if (DEBUG) {
                $logger->line('Acktor Hierarchy') if DEBUG;
                $self->print_actor_tree($root);
            }

            next if $timers->has_timers;

            if (my $usr = $lookup{ '//usr' } ) {
                if ( $usr->is_alive && !$usr->children ) {
                    $logger->alert("ENTERING SHUTDOWN") if DEBUG;
                    $root->context->stop;
                }
            }

            last unless @mailboxes;
        }
        $logger->line('end:loop') if DEBUG;
    }

    method print_actor_tree ($ref, $indent='') {
        $logger->log(DEBUG, sprintf '%s<%s>[%03d]' => $indent, $ref->context->props->class, $ref->pid ) if DEBUG;
        $indent .= '  ';
        foreach my $child ( $ref->context->children ) {
            $self->print_actor_tree( $child, $indent );
        }
    }

}


