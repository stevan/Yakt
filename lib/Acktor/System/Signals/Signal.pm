#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];


class Acktor::System::Signals::Signal {
    use overload '""' => 'to_string';

    method to_string { blessed $self }
}
