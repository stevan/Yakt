#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Acktor::System::Signals {
    use Acktor::System::Signals::Signal;
    use Acktor::System::Signals::Started;
    use Acktor::System::Signals::Stopping;
    use Acktor::System::Signals::Restarting;
    use Acktor::System::Signals::Stopped;
    use Acktor::System::Signals::Terminated;
    use Acktor::System::Signals::Ready;
}
