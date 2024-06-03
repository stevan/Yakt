#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Acktor::System::Signals::IO {
    use Acktor::System::Signals::IO::Signal;
    use Acktor::System::Signals::IO::CanRead;
    use Acktor::System::Signals::IO::CanWrite;
    use Acktor::System::Signals::IO::CanAccept;
    use Acktor::System::Signals::IO::IsConnected;
    use Acktor::System::Signals::IO::GotConnectionError;
    use Acktor::System::Signals::IO::GotError;
}
