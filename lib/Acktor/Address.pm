#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Address {
    field $host :param = '0.0.0.0';
    field $path :param = +[];
    field $pid  :param = undef;

    my sub normalize_path ($p) { ref $p ? $p : [ grep $_, split '/' => $p ] }

    ADJUST { $path = normalize_path($path) }

    method pid  { sprintf('%04d', $pid) }
    method host { $host }
    method path { join '/' => @$path, $self->pid }
    method url  { join '/' => $host, $self->path }

    method with_path (@p) {
        Acktor::Address->new(
            host => $host,
            path => [ @$path, map normalize_path($_)->@*, @p ],
            pid  => $pid
        )
    }

    method with_pid ($pid) {
        Acktor::Address->new(
            host => $host,
            path => [ @$path ],
            pid  => $pid
        )
    }
}
