#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Acktor::Signals::IO {
    use Acktor::Signals::IO::Signal;
    use Acktor::Signals::IO::CanRead;
    use Acktor::Signals::IO::CanWrite;
    use Acktor::Signals::IO::CanAccept;
    use Acktor::Signals::IO::IsConnected;
    use Acktor::Signals::IO::GotConnectionError;
    use Acktor::Signals::IO::GotError;
}
