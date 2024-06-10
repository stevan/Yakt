#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::Signals::Signal;

class Acktor::System::Signals::IO::Signal :isa(Acktor::System::Signals::Signal) {}
