#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Signals::Signal;

class Acktor::Signals::Restarting :isa(Acktor::Signals::Signal) {}

