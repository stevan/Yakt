#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::System::Supervisors::Supervisor {
    use Yakt::Logging;

    use constant RESUME => 1;
    use constant RETRY  => 2;
    use constant HALT   => 3;

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method supervise ($context, $e) {
        $logger->log(INTERNALS, "!!! OH NOES, we got an error ($e)" ) if INTERNALS;
    }
}
