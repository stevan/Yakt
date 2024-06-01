#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::IO::Signals;

class Acktor::IO::Watcher {
    use Acktor::Logging;

    field $ref     :param;
    field $fh      :param;
    field $reading :param = false;
    field $writing :param = false;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__."<$fh>[$ref]") if LOG_LEVEL;

        $fh->autoflush(1);
        $fh->blocking(0);
    }

    method fh { $fh }

    method is_reading :lvalue { $reading }
    method is_writing :lvalue { $writing }

    method is_active { $reading || $writing }

    method can_read {
        $logger->log( WARN, "got Can Read" ) if WARN;
        $ref->context->notify( Acktor::IO::Signals::CanRead->new );
    }

    method can_write {
        $logger->log( WARN, "got Can Write" ) if WARN;
        $ref->context->notify( Acktor::IO::Signals::CanWrite->new );
    }
}
