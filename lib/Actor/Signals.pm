#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Signal;

class Actor::Signals::Activated   :isa(Actor::Signal) {}
class Actor::Signals::Deactivated :isa(Actor::Signal) {}

class Actor::Signals {
    use constant ACTIVATED   => Actor::Signals::Activated->new;
    use constant DEACTIVATED => Actor::Signals::Deactivated->new;
}
