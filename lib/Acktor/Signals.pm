#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Actor::Signals {
    use Acktor::Signals::Signal;
    use Acktor::Signals::Started;
    use Acktor::Signals::Stopping;
    use Acktor::Signals::Restarting;
    use Acktor::Signals::Stopped;
    use Acktor::Signals::Terminated;
}
