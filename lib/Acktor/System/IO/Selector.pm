#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::System::IO::Selector {
    use Acktor::Logging;

    use overload '""' => 'to_string';

    field $ref :param;
    field $fh  :param;

    ADJUST {
        $fh->autoflush(1);
        $fh->blocking(0);
    }

    method ref { $ref }
    method fh  { $fh  }

    method watch_for_read;
    method watch_for_write;
    method watch_for_error;

    method reset;

    method is_active;

    method can_read;
    method can_write;
    method got_error;

    method to_string { sprintf "Selector(%s)->%s", blessed $fh, $ref->to_string }
}

__END__

=pod

For non-blocking Connection steal from this:

https://metacpan.org/dist/IO-Socket-IP/source/lib/IO/Socket/IP.pm#L700

Selects:

In summary, a socket will be identified in a particular set when select returns if:

Readable:

- If listen has been called and a connection is pending, accept will succeed.
- Data is available for reading (includes OOB data if SO_OOBINLINE is enabled).
- Connection has been closed/reset/terminated.

Writeable:

- If processing a connect call (nonblocking), connection has succeeded.
- Data can be sent.

Exception:

- If processing a connect call (nonblocking), connection attempt failed.
- OOB data is available for reading (only if SO_OOBINLINE is disabled).

- Watchers are for non-blocking streams
    - streams are:
        - sockets
            - most forms of `connect` are async
            - `accept` is mostly async
        - pipes
        - tty (STDIN, STDOUT, STDERR)
        - opened filehandle reading/writing

- Watchers are NOT for blocking operations
    - what can't be async:
        - disk access (open, unlink, etc.)
        - some forms of `connect` are not async
            - SSL is one example
            - things that call gethost* stuff

=cut
