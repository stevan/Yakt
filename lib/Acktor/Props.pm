#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Supervisors;
use Acktor::Behavior;

class Acktor::Props {
    use overload '""' => \&to_string;

    field $class :param;
    field $args  :param = {};
    field $alias :param = undef;

    method class { $class }
    method alias { $alias }

    method new_actor {
        say "++ $self -> new_actor($class)";
        $class->new( %$args )
    }

    method new_supervisor { Acktor::Supervisors::Restart->new }
    method new_behavior   { Acktor::Behavior->new }

    method to_string { "Props[$class]" }
}

