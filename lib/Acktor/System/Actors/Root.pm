#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;
use Acktor::Props;
use Acktor::System::Actors::System;
use Acktor::System::Actors::Users;

class Acktor::System::Actors::Root :isa(Acktor) {
    use Acktor::Logging;

    field $init :param;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method post_start  ($context) {
        $logger->log(INTERNALS, sprintf 'Started %s' => $context->self ) if INTERNALS;

        $context->spawn( Acktor::Props->new(
            class => 'Acktor::System::Actors::System',
            alias => '//sys'
        ));
        $context->spawn( Acktor::Props->new(
            class => 'Acktor::System::Actors::Users',
            alias => '//usr',
            args  => { init => $init }
        ));
    }
}
