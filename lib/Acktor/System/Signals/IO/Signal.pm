#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::System::Signals::Signal;

class Acktor::System::Signals::IO::Signal :isa(Acktor::System::Signals::Signal) {}
