#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Acktor::System';

use Acktor::Streams;

use Acktor::System::Signals::IO;

use Acktor::System::IO::Selector::Stream;

use Acktor::System::IO::Reader::LineBuffered;
use Acktor::System::IO::Writer::LineBuffered;

class Acktor::IO::Stream::ObservableReader :isa(Acktor) {
    use Acktor::Logging;

    field $observer :param;
    field $fh       :param;

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
        $watcher->is_reading = true;
    }

    method on_stopping :Signal(Acktor::System::Signals::Stopping) ($context, $signal) {
        $context->logger->log(INFO, "Stopping, removing watcher for fh($fh) ... ") if INFO;
        $context->system->io->remove_selector( $watcher );
    }

    # ... IO Signals

    method can_read :Signal(Acktor::System::Signals::IO::CanRead) ($context, $signal) {
        if ($read_buffer->read($fh)) {
            $context->logger->log(INFO, "Read bytes from fh($fh)") if INFO;
            if (my @lines = $read_buffer->flush_buffer) {
                $context->logger->log(INFO, "Got ".(scalar @lines)." lines reading fh($fh)") if INFO;
                $observer->send(Acktor::Streams::OnNext->new( value => $_ ))
                    foreach @lines;
            }
            else {
                $context->logger->log(INFO, "No lines read from fh($fh)") if INFO;
            }
        }

        if (my $e = $read_buffer->got_error) {
            $context->logger->log(ERROR, "Got error($e) reading fh($fh)") if ERROR;
            $observer->send(Acktor::Streams::OnError->new( error => $e ));
            $watcher->is_reading = false;
        }

        if ($read_buffer->got_eof) {
            $context->logger->log(INFO, "Got EOF reading fh($fh)") if INFO;
            $observer->send(Acktor::Streams::OnCompleted->new);
            $watcher->is_reading = false;
        }
    }
}

class BufferedFileReader :isa(Acktor) {
    use Acktor::Logging;

    field $fh :param;

    field $stream;
    field @lines;

    our %BUFFERS;

    method on_start :Signal(Acktor::System::Signals::Started) ($context, $signal) {
        $stream = $context->spawn(Acktor::Props->new( class => 'Acktor::IO::Stream::ObservableReader', args => {
            observer => $context->self,
            fh       => $fh
        }));
    }

    my sub dump_buffer ($context, $lines) {
        my $num = 0;
        $context->logger->log(INFO, join "\n" => map { sprintf '%3d : %s', ++$num, $_ } @$lines) if INFO;
    }

    method got_line :Receive(Acktor::Streams::OnNext) ($context, $message) {
        my $line = $message->value;
        $context->logger->log(INFO, "Got OnNext with line($line) ...") if INFO;
        push @lines => $line;
    }

    method got_eof :Receive(Acktor::Streams::OnCompleted) ($context, $message) {
        $context->logger->log(INFO, "Got OnCompleted ... dumping buffer") if INFO;
        dump_buffer( $context, \@lines );
        $BUFFERS{$fh} = \@lines;
        $context->stop;
    }

    method got_error :Receive(Acktor::Streams::OnError) ($context, $message) {
        $context->logger->log(INFO, "Got OnError ... dumping buffer") if INFO;
        dump_buffer( $context, \@lines );
        $context->stop;
    }
}

my $fh1 = IO::File->new;

$fh1->open(__FILE__, 'r');

my $fh2 = IO::File->new;

$fh2->open('t/300-io.t', 'r');

my $sys = Acktor::System->new->init(sub ($context) {
    my $o1 = $context->spawn(Acktor::Props->new( class => 'BufferedFileReader', args => { fh => $fh1 } ));
    my $o2 = $context->spawn(Acktor::Props->new( class => 'BufferedFileReader', args => { fh => $fh2 } ));
});

$sys->loop_until_done;

is($BufferedFileReader::BUFFERS{$fh1}->[-1], '# THE END', '... got the expected last line for fh 1');
is($BufferedFileReader::BUFFERS{$fh2}->[-1], 'done_testing;', '... got the expected last line for fh 2');

done_testing;

# THE END
