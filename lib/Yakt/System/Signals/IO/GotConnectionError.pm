#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Signals::IO::Signal;

class Yakt::System::Signals::IO::GotConnectionError :isa(Yakt::System::Signals::IO::Signal) {}
