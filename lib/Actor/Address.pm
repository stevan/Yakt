#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Address {
    field $host :param = '0';
    field $path :param = +[];

    my sub normalize_path ($p) { ref $p ? $p : [ grep $_, split '/' => $p ] }

    ADJUST { $path = normalize_path($path) }

    method host { $host                          }
    method path { join '/' => @$path             }
    method url  { join '/' => $host, $self->path }

    method with_path (@p) {
        Actor::Address->new(
            host => $host,
            path => [ @$path, map normalize_path($_)->@*, @p ]
        )
    }
}
