#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Supervisors;
use Acktor::Behavior;

class Acktor::Props {
    use Acktor::Logging;

    use overload '""' => \&to_string;

    field $class :param;
    field $args  :param = {};
    field $alias :param = undef;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method class { $class }
    method alias { $alias }

    method new_actor {
        $logger->log(DEBUG, "++ $self -> new_actor($class)" ) if DEBUG;
        $class->new( %$args )
    }

    method new_supervisor { Acktor::Supervisors::Restart->new }
    method new_behavior   { Acktor::Behavior->new }

    method to_string { "Props[$class]" }
}

