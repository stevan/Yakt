#!perl

use v5.40;
use experimental qw[ class ];

class Acktor::System::Supervisors::Supervisor {
    use Acktor::Logging;

    use constant RESUME => 1;
    use constant RETRY  => 2;
    use constant HALT   => 3;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method supervise ($context, $e) {
        $logger->log(INTERNALS, "!!! OH NOES, we got an error ($e)" ) if INTERNALS;
    }
}
