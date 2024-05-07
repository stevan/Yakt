#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Props {
    field $class :param;
    field $args  :param = +{};

    method class { $class }
    method args  { $args  }

    method new_actor {
        $class->new( %$args )
    }

    method behavior_for_actor {
        # replace this later, it should be something like
        # Behaviors->for_class($class)
        $class->BEHAVIOR
    }
}
