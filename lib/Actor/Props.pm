#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Behavior;
use Actor::Supervisors;

class Actor::Props {
    use Actor::Logging;

    field $class :param;
    field $args  :param = +{};

    field $logger;

    ADJUST {
        $logger = Actor::Logging->logger( "Props[$class]" ) if LOG_LEVEL;
    }

    method class { $class }
    method args  { $args  }

    method new_actor {
        $logger->log(DEBUG, "Creating new actor for ($class)") if DEBUG;
        $class->new( %$args )
    }

    method behavior_for_actor {
        # XXX - Yuk, fixme
        $class->can('BEHAVIOR')
            ? $class->BEHAVIOR
            : Actor::Behavior->new;
    }

    method supervisor_for_actor {
        # XXX - Yuk, fixme
        $class->can('SUPERVISOR')
            ? $class->SUPERVISOR
            : Actor::Supervisors->Stop;
    }
}
