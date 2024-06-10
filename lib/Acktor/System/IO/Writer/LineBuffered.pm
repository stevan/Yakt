#!perl

use v5.40;
use experimental qw[ class ];

class Acktor::System::IO::Writer::LineBuffered {
    use Acktor::Logging;

    field @buffer;
    field $error;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method can_write { !! @buffer }

    method buffered_write (@to_write) { push @buffer => @to_write }

    method write ($fh) {
        $logger->log( DEBUG, "write event for ($fh)" ) if DEBUG;
        while (@buffer) {
            my $line = pop @buffer;

            $logger->log( DEBUG, "Writing line ...[ $line ]" ) if DEBUG;
            $fh->syswrite( $line, length($line) );
        }

        # returns false if all letters
        # have been sent, true otherwise
        return !! scalar @buffer;
    }

}

