#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Signals {}

# -------------------------------------------------------------------
# Signal class
# -------------------------------------------------------------------

class Actor::Signal {}

# -------------------------------------------------------------------
# Lifecycle Signals
# -------------------------------------------------------------------
#
# - Started
#     - the actor has been activated, this will be the first signal
#       that it receives
#
# - Stopping
#     - the actor is being shut down, and is about to be stopped
#
# - Restarting
#     - the actor is being shut down, and is about to be restarted
#
# - Stopped
#     - the actor has been shut down and will be removed
#
# -------------------------------------------------------------------

class Actor::Signals::Lifecycle::Started    :isa(Actor::Signal) {}
class Actor::Signals::Lifecycle::Stopping   :isa(Actor::Signal) {}
class Actor::Signals::Lifecycle::Restarting :isa(Actor::Signal) {}
class Actor::Signals::Lifecycle::Stopped    :isa(Actor::Signal) {}

class Actor::Signals::Lifecycle {
    use constant Started    => Actor::Signals::Lifecycle::Started->new;
    use constant Stopping   => Actor::Signals::Lifecycle::Stopping->new;
    use constant Restarting => Actor::Signals::Lifecycle::Restarting->new;
    use constant Stopped    => Actor::Signals::Lifecycle::Stopped->new;
}
