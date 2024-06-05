
use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::System::IO::Reader::LineBuffered {
    use Acktor::Logging;

    use Errno 'EWOULDBLOCK';

    use constant MAX_BUFFER => 4096;

    field $buffer_size :param = MAX_BUFFER;

    field $buffer = '';
    field $eof    = false;
    field $error;
    field @buffer;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method got_error {   $error }
    method got_eof   {     $eof }
    method is_empty  { ! @buffer }

    method flush_buffer { my @b = @buffer; @buffer = (); @b; }

    method parse_buffer {
        return unless $buffer =~ /\n/;

        my @line = split /\n/ => $buffer;
        #use Data::Dumper;
        #warn Dumper \@line;

        if ($buffer !~ /\n$/) {
            #warn "B Buffer: $buffer";
            $buffer = pop @line;
            #warn "A Buffer: $buffer";
        }
        else {
            #warn "BUFFER: $buffer";
            $buffer = '';
        }

        push @buffer => @line;
    }

    method read ($fh) {
        $logger->log( DEBUG, "read($buffer_size) started with buffer($buffer)" ) if DEBUG;

        my $bytes_read = $fh->sysread( $buffer, $buffer_size, length $buffer );

        if (defined $bytes_read) {
            if ($bytes_read > 0) {
                $logger->log( DEBUG, "read bytes($bytes_read) into buffer($buffer)" ) if DEBUG;
                $self->parse_buffer;
            }
            else {
                $logger->log( DEBUG, "got EOF with buffer($buffer)" ) if DEBUG;
                $eof = true;
            }
        } elsif ($! == EWOULDBLOCK) {
            $logger->log( DEBUG, "would block, with buffer($buffer)" ) if DEBUG;
        } else {
            $logger->log( ERROR, "sysread error($!), with buffer($buffer)" ) if ERROR;
            $error = $!;
        }

        # returns true if we
        # have read buffer
        # and false if not
        return !! scalar @buffer;
    }

}
