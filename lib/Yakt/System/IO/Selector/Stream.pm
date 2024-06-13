#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::IO::Selector;
use Yakt::System::Signals::IO;

class Yakt::System::IO::Selector::Stream :isa(Yakt::System::IO::Selector) {
    use Yakt::Logging;

    field $reading :param = false;
    field $writing :param = false;

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger('System::Timers') if LOG_LEVEL;
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
        $self->ref->context->notify( Yakt::System::Signals::IO::CanRead->new );
    }

    method can_write {
        $logger->log( DEBUG, "got Can Write" ) if DEBUG;
        $self->ref->context->notify( Yakt::System::Signals::IO::CanWrite->new );
    }

    method got_error {
        $logger->log( DEBUG, "got Error" ) if DEBUG;
        $self->ref->context->notify( Yakt::System::Signals::IO::GotError->new );
    }
}
