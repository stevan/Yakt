#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Supervisors;
use Acktor::Behavior;

class Acktor::Props {
    use Acktor::Logging;

    use overload '""' => \&to_string;

    field $class      :param;
    field $args       :param = {};
    field $alias      :param = undef;
    field $supervisor :param = undef;
    field $behavior   :param = undef;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method class { $class }
    method alias { $alias }

    method with_supervisor ($s) { $supervisor = $s; $self }
    method with_behavior   ($b) { $behavior   = $b; $self }

    method new_actor {
        $logger->log(DEBUG, "++ $self -> new_actor($class)" ) if DEBUG;
        $class->new( %$args )
    }

    method new_supervisor { $supervisor //= Acktor::Supervisors::Stop->new }
    method new_behavior   { $behavior   //= Acktor::Behavior->new          }

    method to_string { "Props[$class]" }
}

