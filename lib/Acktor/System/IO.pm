
use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Signals::IO;

use Acktor::System::IO::Selector;
use Acktor::System::IO::Selector::Stream;
use Acktor::System::IO::Selector::Socket;

class Acktor::System::IO {
    use Acktor::Logging;

    use IO::Select;

    field @selectors;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

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
                $logger->log( DEBUG, "... adding fh($fh) to select read" ) if DEBUG;
                $readers->add( $fh );
            }

            if ($watcher->watch_for_write) {
                push @{ $to_write{ $fh } //= [] } => $watcher;
                $logger->log( DEBUG, "... adding fh($fh) to select write" ) if DEBUG;
                $writers->add( $fh );
            }

            if ($watcher->watch_for_error) {
                push @{ $got_error{ $fh } //= [] } => $watcher;
                $logger->log( DEBUG, "... adding fh($fh) to select error" ) if DEBUG;
                $errors->add( $fh );
            }
        }

        my ($r, $w, $e) = IO::Select::select($readers, $writers, $errors, $timeout);

        if (!defined $r && !defined $w && !defined $e) {
            $logger->log( DEBUG, "... no events to see, looping" ) if DEBUG;
            return;
        }

        map $_->got_error, map $_->@*, @got_error{ @$e } if $e;
        map $_->can_read,  map $_->@*, @to_read  { @$r } if $r;
        map $_->can_write, map $_->@*, @to_write { @$w } if $w;
    }

}
