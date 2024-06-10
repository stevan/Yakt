#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::IO::Selector;
use Acktor::System::Signals::IO;

class Acktor::System::IO::Selector::Stream :isa(Acktor::System::IO::Selector) {
    use Acktor::Logging;

    field $reading :param = false;
    field $writing :param = false;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger('System::Timers') if LOG_LEVEL;
    }

    method watch_for_read  { $reading }
    method watch_for_write { $writing }
    method watch_for_error { false    }

    method is_reading :lvalue { $reading }
    method is_writing :lvalue { $writing }

    method reset {
        $reading = false;
        $writing = false;
    }

    method is_active { $reading || $writing }

    method can_read {
        $logger->log( DEBUG, "got Can Read" ) if DEBUG;
        $self->ref->context->notify( Acktor::System::Signals::IO::CanRead->new );
    }

    method can_write {
        $logger->log( DEBUG, "got Can Write" ) if DEBUG;
        $self->ref->context->notify( Acktor::System::Signals::IO::CanWrite->new );
    }

    method got_error {
        $logger->log( DEBUG, "got Error" ) if DEBUG;
        $self->ref->context->notify( Acktor::System::Signals::IO::GotError->new );
    }
}
