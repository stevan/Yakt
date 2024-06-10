#!perl

use v5.40;
use experimental qw[ class ];

package Acktor::System::Signals {
    use Acktor::System::Signals::Signal;
    use Acktor::System::Signals::Started;
    use Acktor::System::Signals::Stopping;
    use Acktor::System::Signals::Restarting;
    use Acktor::System::Signals::Stopped;
    use Acktor::System::Signals::Terminated;
    use Acktor::System::Signals::Ready;
}
