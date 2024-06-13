#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::System::Timers::Timer {
    field $timeout  :param;
    field $callback :param;

    field $cancelled = false;

    method timeout  { $timeout  }
    method callback { $callback }

    method cancel    { $cancelled = true }
    method cancelled { $cancelled }
}
