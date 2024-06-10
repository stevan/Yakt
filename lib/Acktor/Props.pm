#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::Supervisors;

class Acktor::Props {
    use Acktor::Logging;

    use overload '""' => \&to_string;

    field $class      :param;
    field $args       :param = {};
    field $alias      :param = undef;
    field $supervisor :param = undef;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger($self->to_string) if LOG_LEVEL;
    }

    method class { $class }
    method alias { $alias }

    method with_supervisor ($s) { $supervisor = $s; $self }
    method supervisor           { $supervisor //= Acktor::System::Supervisors::Stop->new }

    method new_actor {
        $logger->log(DEBUG, "$self creating new actor($class)" ) if DEBUG;
        $class->new( %$args );
    }

    method to_string { "Props[$class]" }
}

