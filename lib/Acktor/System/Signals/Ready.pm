#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::Signals::Signal;

class Acktor::System::Signals::Ready :isa(Acktor::System::Signals::Signal) {
    field $ref :param;

    method ref { $ref }
}
