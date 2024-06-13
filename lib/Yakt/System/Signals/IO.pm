#!perl

use v5.40;
use experimental qw[ class ];

package Yakt::System::Signals::IO {
    use Yakt::System::Signals::IO::Signal;
    use Yakt::System::Signals::IO::CanRead;
    use Yakt::System::Signals::IO::CanWrite;
    use Yakt::System::Signals::IO::CanAccept;
    use Yakt::System::Signals::IO::IsConnected;
    use Yakt::System::Signals::IO::GotConnectionError;
    use Yakt::System::Signals::IO::GotError;
}
