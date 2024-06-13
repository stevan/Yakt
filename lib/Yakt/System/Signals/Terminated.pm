#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Signals::Signal;

class Yakt::System::Signals::Terminated :isa(Yakt::System::Signals::Signal) {
    field $ref :param;

    method ref { $ref }
}
