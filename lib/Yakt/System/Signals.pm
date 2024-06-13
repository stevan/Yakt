#!perl

use v5.40;
use experimental qw[ class ];

package Yakt::System::Signals {
    use Yakt::System::Signals::Signal;
    use Yakt::System::Signals::Started;
    use Yakt::System::Signals::Stopping;
    use Yakt::System::Signals::Restarting;
    use Yakt::System::Signals::Stopped;
    use Yakt::System::Signals::Terminated;
    use Yakt::System::Signals::Ready;
}
