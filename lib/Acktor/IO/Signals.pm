#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Actor::IO::Signals {
    use Acktor::IO::Signals::Signal;
    use Acktor::IO::Signals::CanRead;
    use Acktor::IO::Signals::CanWrite;
}
