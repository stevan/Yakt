#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Actor::Signal;

# -------------------------------------------------------------------
# Lifecycle Signals
# -------------------------------------------------------------------
#
# - Activated
#
# This is a signal that is passed to the object *after* it has
# been activated. This event is sent internally and should never
# be sent by the user.
#
# - Deactivated
#
# This is a signal that is passed to the object *before* it will
# be deactivated. This event is sent internally and should never
# be sent by the user.
#
# -------------------------------------------------------------------

class Actor::Signals::Lifecycle::Activated   :isa(Actor::Signal) {}
class Actor::Signals::Lifecycle::Deactivated :isa(Actor::Signal) {}

class Actor::Signals::Lifecycle {
    use constant ACTIVATED   => Actor::Signals::Lifecycle::Activated->new;
    use constant DEACTIVATED => Actor::Signals::Lifecycle::Deactivated->new;
}
