#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Signals::Signal;

class Yakt::System::Signals::Stopping :isa(Yakt::System::Signals::Signal) {}
