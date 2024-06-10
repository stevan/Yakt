#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::Signals::Signal;

class Acktor::System::Signals::Stopped :isa(Acktor::System::Signals::Signal) {}
