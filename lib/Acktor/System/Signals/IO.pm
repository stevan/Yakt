#!perl

use v5.40;
use experimental qw[ class ];

package Acktor::System::Signals::IO {
    use Acktor::System::Signals::IO::Signal;
    use Acktor::System::Signals::IO::CanRead;
    use Acktor::System::Signals::IO::CanWrite;
    use Acktor::System::Signals::IO::CanAccept;
    use Acktor::System::Signals::IO::IsConnected;
    use Acktor::System::Signals::IO::GotConnectionError;
    use Acktor::System::Signals::IO::GotError;
}
