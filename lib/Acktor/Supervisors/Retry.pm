#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Supervisors::Supervisor;

class Acktor::Supervisors::Retry :isa(Acktor::Supervisors::Supervisor) {
    use Acktor::Logging;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method supervise ($context, $e) {
        $logger->log(INTERNALS, "!!! OH NOES, we got an error ($e) RETRYING" ) if INTERNALS;
        return $self->RETRY;
    }
}
