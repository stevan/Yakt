#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::System::IO::Writer::LineBuffered {
    use Yakt::Logging;

    field @buffer;
    field $error;

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method buffered_write (@to_write) { push @buffer => @to_write }

    method write ($fh) {
        $logger->log( DEBUG, "write event for ($fh)" ) if DEBUG;
        while (@buffer) {
            my $line = shift @buffer;

            $logger->log( DEBUG, "Writing line ...[ $line ]" ) if DEBUG;
            $line .= "\n" unless $line =~ /\n$/;

            $fh->syswrite( $line, length($line) );
        }

        # returns false if all letters
        # have been sent, true otherwise
        return !! scalar @buffer;
    }

}

