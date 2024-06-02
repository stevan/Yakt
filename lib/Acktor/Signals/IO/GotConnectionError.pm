#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Signals::IO::Signal;

class Acktor::Signals::IO::GotConnectionError :isa(Acktor::Signals::IO::Signal) {}
