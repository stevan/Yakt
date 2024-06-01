
use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::System::IO {
    use Acktor::Logging;

    use IO::Select;

    field @watchers;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method add_watcher ($watcher) {
        push @watchers => $watcher;
    }

    method remove_watcher ($watcher) {
        @watchers = grep { refaddr $watcher != refaddr $_ } @watchers;
    }

    method has_active_watchers {
        !! scalar grep $_->is_active, @watchers;
    }

    ## ...

    method tick ($timeout) {
        local $! = 0;

        $logger->log( DEBUG, "tick w/ timeout($timeout) ..." ) if DEBUG;

        my @to_watch = grep $_->is_active, @watchers;

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

        my %to_read;
        my %to_write;

        foreach my $watcher (@to_watch) {
            my $fh = $watcher->fh;

            if ($watcher->is_reading) {
                #say "adding read watcher ($fh) ($watcher)";
                push @{ $to_read{ $fh } //= [] } => $watcher;
                $logger->log( DEBUG, "... adding fh($fh) to select read" ) if DEBUG;
                $readers->add( $fh );
            }

            if ($watcher->is_writing) {
                #say "adding write watcher ($fh) ($watcher)";
                push @{ $to_write{ $fh } //= [] } => $watcher;
                $logger->log( DEBUG, "... adding fh($fh) to select write" ) if DEBUG;
                $writers->add( $fh );
            }
        }

        my @handles = IO::Select::select(
            $readers,
            $writers,
            undef, # TODO: fix me when I know when I am doing
            $timeout
        );

        my ($r, $w, undef) = @handles;

        if (!defined $r && !defined $w) {
            $logger->log( DEBUG, "... no events to see, looping" ) if DEBUG;
            return;
        }

        foreach my $fh (@{ $r // [] }) {
            foreach my $watcher ( $to_read{$fh}->@* ) {
                $watcher->can_read;
            }
        }
        foreach my $fh (@{ $w // [] }) {
            foreach my $watcher ( $to_write{$fh}->@* ) {
                $watcher->can_write;
            }
        }
    }

}
