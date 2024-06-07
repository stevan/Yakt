#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

use Acktor::System::Signals::IO;

use Acktor::System::IO::Selector::Stream;

use Acktor::System::IO::Reader::LineBuffered;
use Acktor::System::IO::Writer::LineBuffered;

class ReadLines :isa(Acktor::System::Messages::Message) {}

class LinesRead :isa(Acktor::System::Messages::Message) {
    field $lines :param;
    method lines { @$lines }
}

class GotEOF   :isa(Acktor::System::Messages::Message) {}
class GotError :isa(Acktor::System::Messages::Error) {}

class IO::Stream::Reader :isa(Acktor) {
    use Acktor::Logging;

    field $fh  :param;
    field $ref :param;

    field $watcher;

    field $read_buffer;
    field @line_buffer;

    ADJUST {
        $read_buffer = Acktor::System::IO::Reader::LineBuffered->new( buffer_size => 128 );
    }

    # ... Signals

    method on_start :Signal(Acktor::System::Signals::Started) ($context, $signal) {
        $context->logger->log(INFO, "Started, creating watcher for fh($fh) ... ") if INFO;
        $watcher = Acktor::System::IO::Selector::Stream->new( ref => $context->self, fh => $fh );
        $context->system->io->add_selector( $watcher );
    }

    # ... IO Signals

    method can_read :Signal(Acktor::System::Signals::IO::CanRead) ($context, $signal) {
        if ($read_buffer->read($fh)) {
            my @lines = $read_buffer->flush_buffer;
            $ref->send(LinesRead->new( lines => \@lines ));
        }

        if (my $e = $read_buffer->got_error) {
            $context->logger->log(ERROR, "Got error($e) reading fh($fh)") if ERROR;
            $ref->send(GotError->new( error => $e ));
            $watcher->is_reading = false;
        }

        if ($read_buffer->got_eof) {
            $context->logger->log(INFO, "Got EOF reading fh($fh)") if INFO;
            $ref->send(GotEOF->new);
            $watcher->is_reading = false;
        }
    }

    # ... IO Messages

    method read_lines :Receive(ReadLines) ($context, $message) {
        $context->logger->log(INFO, "Got ReadLines ...") if INFO;
        $watcher->is_reading = true;
    }
}

class Reader :isa(Acktor) {
    use Acktor::Logging;

    field $fh :param;

    field $stream;
    field @lines;

    our %BUFFERS;

    method on_start :Signal(Acktor::System::Signals::Started) ($context, $signal) {
        $stream = $context->spawn(Acktor::Props->new( class => 'IO::Stream::Reader', args => {
            ref => $context->self,
            fh  => $fh
        }));

        $stream->send(ReadLines->new);
    }

    method dump_buffer ($context) {
        my $num = 0;
        $context->logger->log(INFO, join "\n" => map { sprintf '%3d : %s', ++$num, $_ } @lines) if INFO;
    }

    method got_lines :Receive(LinesRead) ($context, $message) {
        $context->logger->log(INFO, "Got LinesRead ...") if INFO;
        push @lines => $message->lines;
        my $num = 0;
        $context->logger->log(INFO, join "\n" => map { sprintf '%3d : %s', ++$num, $_ } $message->lines) if INFO;
    }

    method got_eof :Receive(GotEOF) ($context, $message) {
        $context->logger->log(INFO, "Got GotEOF ... dumping buffer") if INFO;
        $self->dump_buffer( $context );
        $BUFFERS{$fh} = \@lines;
        $context->stop;
    }

    method got_error :Receive(GotError) ($context, $message) {
        $context->logger->log(INFO, "Got GotError ... dumping buffer") if INFO;
        $self->dump_buffer( $context );
        $context->stop;
    }
}

my $fh1 = IO::File->new;

$fh1->open(__FILE__, 'r');

my $fh2 = IO::File->new;

$fh2->open('t/300-io.t', 'r');

my $sys = Acktor::System->new->init(sub ($context) {
    my $o1 = $context->spawn(Acktor::Props->new( class => 'Reader', args => { fh => $fh1 } ));
    my $o2 = $context->spawn(Acktor::Props->new( class => 'Reader', args => { fh => $fh2 } ));
});

$sys->loop_until_done;

is($Reader::BUFFERS{$fh1}->[-1], '# THE END', '... got the expected last line for fh 1');
is($Reader::BUFFERS{$fh2}->[-1], 'done_testing;', '... got the expected last line for fh 2');

done_testing;

# THE END
