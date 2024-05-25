#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Timer {
    field $timeout  :param;
    field $callback :param;

    field $cancelled = false;

    method timeout  { $timeout  }
    method callback { $callback }

    method cancel    { $cancelled = true }
    method cancelled { $cancelled }
}
