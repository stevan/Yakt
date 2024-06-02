#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::IO::Selector;
use Acktor::Signals::IO;

class Acktor::IO::Selector::Socket :isa(Acktor::IO::Selector) {
    use Acktor::Logging;

    field $connecting :param = false;
    field $listening  :param = false;
    field $reading    :param = false;
    field $writing    :param = false;

    method watch_for_read  { $reading || $listening  }
    method watch_for_write { $writing || $connecting }
    method watch_for_error { $connecting }

    method is_connecting :lvalue { $connecting }
    method is_listening  :lvalue { $listening  }
    method is_reading    :lvalue { $reading    }
    method is_writing    :lvalue { $writing    }

    method reset {
        $reading    = false;
        $writing    = false;
        $connecting = false;
        $listening  = false;
    }

    method is_active { $reading || $writing || $connecting || $listening }

    method can_read {
        if ( $listening ) {
            $self->logger->log( WARN, "got Can Accept" ) if WARN;
            $self->ref->context->notify( Acktor::Signals::IO::CanAccept->new );
        } else {
            $self->logger->log( WARN, "got Can Read" ) if WARN;
            $self->ref->context->notify( Acktor::Signals::IO::CanRead->new );
        }
    }

    method can_write {
        if ( $connecting ) {
            $self->logger->log( WARN, "got Is Connected" ) if WARN;
            $self->ref->context->notify( Acktor::Signals::IO::IsConnected->new );
        } else {
            $self->logger->log( WARN, "got Can Write" ) if WARN;
            $self->ref->context->notify( Acktor::Signals::IO::CanWrite->new );
        }
    }

    method got_error {
        if ( $connecting ) {
            $self->logger->log( WARN, "got Connection Error" ) if WARN;
            $self->ref->context->notify( Acktor::Signals::IO::GotConnectionError->new );
        } else {
            $self->logger->log( WARN, "got Error" ) if WARN;
            $self->ref->context->notify( Acktor::Signals::IO::GotError->new );
        }
    }
}

