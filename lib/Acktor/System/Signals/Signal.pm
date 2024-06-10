#!perl

use v5.40;
use experimental qw[ class ];


class Acktor::System::Signals::Signal {
    use overload '""' => 'to_string';

    method to_string { blessed $self }
}
