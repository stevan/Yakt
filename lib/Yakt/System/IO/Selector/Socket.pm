#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::IO::Selector;
use Yakt::System::Signals::IO;

class Yakt::System::IO::Selector::Socket :isa(Yakt::System::IO::Selector) {
    use Yakt::Logging;

    field $connecting :param = false;
    field $listening  :param = false;
    field $reading    :param = false;
    field $writing    :param = false;

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger('System::Timers') if LOG_LEVEL;
    }

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
            $logger->log( DEBUG, "got Can Accept" ) if DEBUG;
            $self->ref->context->notify( Yakt::System::Signals::IO::CanAccept->new );
        } else {
            $logger->log( DEBUG, "got Can Read" ) if DEBUG;
            $self->ref->context->notify( Yakt::System::Signals::IO::CanRead->new );
        }
    }

    method can_write {
        if ( $connecting ) {
            $logger->log( DEBUG, "got Is Connected" ) if DEBUG;
            $self->ref->context->notify( Yakt::System::Signals::IO::IsConnected->new );
        } else {
            $logger->log( DEBUG, "got Can Write" ) if DEBUG;
            $self->ref->context->notify( Yakt::System::Signals::IO::CanWrite->new );
        }
    }

    method got_error {
        if ( $connecting ) {
            $logger->log( DEBUG, "got Connection Error" ) if DEBUG;
            $self->ref->context->notify( Yakt::System::Signals::IO::GotConnectionError->new );
        } else {
            $logger->log( DEBUG, "got Error" ) if DEBUG;
            $self->ref->context->notify( Yakt::System::Signals::IO::GotError->new );
        }
    }

}

