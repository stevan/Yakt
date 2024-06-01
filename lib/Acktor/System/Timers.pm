#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Time::HiRes;

class Acktor::System::Timers {
    use Acktor::Logging;

    our $TIMER_PRECISION_DECIMAL = 0.001;
    our $TIMER_PRECISION_INT     = 1000;

    field $time;
    field @timers;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger('System::Timers') if LOG_LEVEL;
    }

    method has_timers { !! @timers }

    method now  {
        state $MONOTONIC = Time::HiRes::CLOCK_MONOTONIC();
        # always stay up to date ...
        $time = Time::HiRes::clock_gettime( $MONOTONIC );
    }

    method wait ($duration) {
        Time::HiRes::sleep( $duration );
    }

    method calculate_end_time ($timer) {
        my $now      = $self->now;
        my $end_time = $now + $timer->timeout;
           $end_time = int($end_time * $TIMER_PRECISION_INT) * $TIMER_PRECISION_DECIMAL;

        return $end_time;
    }

    method schedule_timer ($timer) {

        # XXX - should this use $time, or should it call ->now to update?
        my $end_time = $self->calculate_end_time($timer);

        if ( scalar @timers == 0 ) {
            # fast track the first one ...
            push @timers => [ $end_time, [ $timer ] ];
        }
        # if the last one is the same time as this one
        elsif ( $timers[-1]->[0] == $end_time ) {
            # then push it onto the same timer slot ...
            push $timers[-1]->[1]->@* => $timer;
        }
        # if the last one is less than this one, we add a new one
        elsif ( $timers[-1]->[0] < $end_time ) {
            push @timers => [ $end_time, [ $timer ] ];
        }
        elsif ( $timers[-1]->[0] > $end_time ) {
            # and only sort when we absolutely have to
            @timers = sort { $a->[0] <=> $b->[0] } @timers, [ $end_time, [ $timer ] ];
            # TODO: since we are sorting we might
            # as well also prune the cancelled ones
        }
        else {
            # NOTE:
            # we could add some more cases here, for instance
            # if the new time is before the last timer, we could
            # also check the begining of the list and `unshift`
            # it there if it made sense, but that is likely
            # micro optimizing this.
            $logger->log(ERROR, "This should never happen") if ERROR;
        }
    }

    method get_next_timer () {
        while (my $next_timer = $timers[0]) {
            # if we have any timers
            if ( $next_timer->[1]->@* ) {
                # if all of them are cancelled
                if ( 0 == scalar grep !$_->cancelled, $next_timer->[1]->@* ) {
                    # drop this set of timers
                    shift @timers;
                    # try again ...
                    next;
                }
                else {
                    last;
                }
            }
            else {
                shift @timers;
            }
        }

        return $timers[0];
    }

    method should_wait {
        my $wait = 0;

        if (my $next_timer = $self->get_next_timer) {
            $wait = $next_timer->[0] - $time
        }

        # do not wait for negative values ...
        if ($wait < $TIMER_PRECISION_DECIMAL) {
            $wait = 0;
        }

        return $wait;
    }

    method pending_timers {
        my $now = $self->now;

        my @t;
        while (@timers && $timers[0]->[0] <= $now) {
            push @t => shift @timers;
        }

        return @t;
    }

    method execute_timer ($timer) {
        while ( $timer->[1]->@* ) {
            my $t = shift $timer->[1]->@*;
            next if $t->cancelled; # skip if the timer has been cancelled
            try {
                $t->callback->();
            } catch ($e) {
                $logger->log( ERROR, "Timer callback failed ($timer) because: $e" ) if ERROR;
            }
        }
    }

    method tick {
        $logger->line( "begin:timers" ) if DEBUG;

        return unless @timers;

        my @timers_to_run = $self->pending_timers;
        return unless @timers_to_run;

        $logger->log( DEBUG, "Got timers to check ... ".scalar @timers) if DEBUG;
        foreach my $timer ( @timers_to_run ) {
            $logger->log( DEBUG, "Running timers ($time) ...") if DEBUG;
            $self->execute_timer( $timer );
        }

        $logger->line( "end:timers" ) if DEBUG;
    }

}


