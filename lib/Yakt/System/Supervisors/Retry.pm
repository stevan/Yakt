#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Supervisors::Supervisor;

class Yakt::System::Supervisors::Retry :isa(Yakt::System::Supervisors::Supervisor) {
    use Yakt::Logging;

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method supervise ($context, $e) {
        $logger->log(INTERNALS, "!!! OH NOES, we got an error ($e) RETRYING" ) if INTERNALS;
        return $self->RETRY;
    }
}
