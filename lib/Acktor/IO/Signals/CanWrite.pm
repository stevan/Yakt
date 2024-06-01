#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::IO::Signals::Signal;

class Acktor::IO::Signals::CanWrite :isa(Acktor::IO::Signals::Signal) {}
