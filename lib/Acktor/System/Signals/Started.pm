#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::System::Signals::Signal;

class Acktor::System::Signals::Started :isa(Acktor::System::Signals::Signal) {}
