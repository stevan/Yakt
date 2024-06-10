#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::Supervisors::Supervisor;

class Acktor::System::Supervisors::Stop :isa(Acktor::System::Supervisors::Supervisor) {
    use Acktor::Logging;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method supervise ($context, $e) {
        $logger->log(INTERNALS, "!!! OH NOES, we got an error ($e) STOPPING" ) if INTERNALS;
        $context->stop;
        return $self->HALT;
    }
}
