#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::Signals::IO::Signal;

class Acktor::System::Signals::IO::GotConnectionError :isa(Acktor::System::Signals::IO::Signal) {}
