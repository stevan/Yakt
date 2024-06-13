
use v5.40;
use experimental qw[ class ];

use Yakt::System::Signals::IO;

use Yakt::System::IO::Selector;
use Yakt::System::IO::Selector::Stream;
use Yakt::System::IO::Selector::Socket;

class Yakt::System::IO {
    use Yakt::Logging;

    use IO::Select;

    field @selectors;

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    ## ...

    method add_selector ($selector) {
        push @selectors => $selector;
    }

    method remove_selector ($selector) {
        @selectors = grep { refaddr $selector != refaddr $_ } @selectors;
    }

    method has_active_selectors {
        !! scalar grep $_->is_active, @selectors;
    }

    ## ...

    method tick ($timeout) {
        local $! = 0;

        if (!@selectors && !$timeout) {
            $logger->log( DEBUG, "... nothing to do, looping" ) if DEBUG;
            return;
        }

        $logger->log( DEBUG, "tick w/ timeout($timeout) ..." ) if DEBUG;

        my @to_watch = grep $_->is_active, @selectors;

        unless (@to_watch) {
            if ($timeout) {
                $logger->log( DEBUG, "... nothing to watch, waiting($timeout)" ) if DEBUG;
                IO::Select::select(undef, undef, undef, $timeout);
            }
            else {
                $logger->log( DEBUG, "... nothing to watch, looping" ) if DEBUG;
            }
            return;
        }

        my $readers = IO::Select->new;
        my $writers = IO::Select->new;
        my $errors  = IO::Select->new;

        my %to_read;
        my %to_write;
        my %got_error;

        foreach my $watcher (@to_watch) {
            my $fh = $watcher->fh;

            if ($watcher->watch_for_read) {
                push @{ $to_read{ $fh } //= [] } => $watcher;
                $logger->log( INTERNALS, "... adding fh(".blessed($fh).") to select read" ) if INTERNALS;
                $readers->add( $fh );
            }

            if ($watcher->watch_for_write) {
                push @{ $to_write{ $fh } //= [] } => $watcher;
                $logger->log( INTERNALS, "... adding fh(".blessed($fh).") to select write" ) if INTERNALS;
                $writers->add( $fh );
            }

            if ($watcher->watch_for_error) {
                push @{ $got_error{ $fh } //= [] } => $watcher;
                $logger->log( INTERNALS, "... adding fh(".blessed($fh).") to select error" ) if INTERNALS;
                $errors->add( $fh );
            }
        }

        my ($r, $w, $e) = IO::Select::select($readers, $writers, $errors, $timeout);

        if (!defined $r && !defined $w && !defined $e) {
            $logger->log( DEBUG, "... no events found, looping" ) if DEBUG;
            return;
        }

        $logger->log( DEBUG, "... got IO events" ) if DEBUG;
        map $_->got_error, map $_->@*, @got_error{ @$e } if $e;
        map $_->can_read,  map $_->@*, @to_read  { @$r } if $r;
        map $_->can_write, map $_->@*, @to_write { @$w } if $w;
        $logger->log( DEBUG, "... finished processing IO events" ) if DEBUG;
    }

}
