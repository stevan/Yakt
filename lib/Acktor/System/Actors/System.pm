#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;
use Acktor::Props;
use Acktor::System::Actors::DeadLetterQueue;

class Acktor::System::Actors::System :isa(Acktor) {
    use Acktor::Logging;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }


    method post_start  ($context) {
        $logger->log(INTERNALS, sprintf 'Started %s' => $context->self ) if INTERNALS;
        $context->spawn( Acktor::Props->new(
            class => 'Acktor::System::Actors::DeadLetterQueue',
            alias => '//sys/dead_letters',
        ));
    }
}
