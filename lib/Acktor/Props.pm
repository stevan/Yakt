#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::System::Supervisors;
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
        $logger = Acktor::Logging->logger($self->to_string) if LOG_LEVEL;
    }

    method class { $class }
    method alias { $alias }

    method with_supervisor ($s) { $supervisor = $s; $self }
    method with_behavior   ($b) { $behavior   = $b; $self }

    method new_actor {
        $logger->log(DEBUG, "$self creating new actor($class)" ) if DEBUG;
        $class->new( %$args )
    }

    method new_supervisor { $supervisor //= Acktor::System::Supervisors::Stop->new }
    method new_behavior   { $behavior   //= Acktor::Behavior->new          }

    method to_string { "Props[$class]" }
}

