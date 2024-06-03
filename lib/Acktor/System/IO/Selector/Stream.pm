#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::System::IO::Selector;
use Acktor::System::Signals::IO;

class Acktor::System::IO::Selector::Stream :isa(Acktor::System::IO::Selector) {
    use Acktor::Logging;

    field $reading :param = false;
    field $writing :param = false;

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
        $self->logger->log( WARN, "got Can Read" ) if WARN;
        $self->ref->context->notify( Acktor::System::Signals::IO::CanRead->new );
    }

    method can_write {
        $self->logger->log( WARN, "got Can Write" ) if WARN;
        $self->ref->context->notify( Acktor::System::Signals::IO::CanWrite->new );
    }

    method got_error {
        $self->logger->log( WARN, "got Error" ) if WARN;
        $self->ref->context->notify( Acktor::System::Signals::IO::GotError->new );
    }
}
