#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams;

use Yakt::System::Signals::IO;

use Yakt::System::IO::Selector::Stream;
use Yakt::System::IO::Reader::LineBuffered;

class Yakt::IO::Actors::StreamReader :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $fh :param;

    field $subscriber;
    field $watcher;
    field $buffer;

    ADJUST {
        $buffer = Yakt::System::IO::Reader::LineBuffered->new( buffer_size => 128 );
    }

    # ... Observable interface

    method subscribe :Receive(Yakt::Streams::Subscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Subscribe called" ) if DEBUG;

        $subscriber = $message->subscriber;
        $subscriber->send( Yakt::Streams::OnSubscribe->new( sender => $context->self ) );

        $context->logger->log(INFO, "Started, creating watcher for fh($fh) ... ") if INFO;
        $watcher = Yakt::System::IO::Selector::Stream->new( ref => $context->self, fh => $fh );
        $context->system->io->add_selector( $watcher );
        $watcher->is_reading = true;
    }

    method unsubscribe :Receive(Yakt::Streams::Unsubscribe) ($context, $message) {
        $context->logger->log(DEBUG, "Unsubscribe called" ) if DEBUG;

        $context->logger->log(INFO, "... removing watcher for fh($fh) ... ") if INFO;
        $context->system->io->remove_selector( $watcher );
        $watcher = undef;

        $subscriber->send( Yakt::Streams::OnUnsubscribe->new );
        $subscriber = undef;

        $context->stop;
    }

    # ... Signals

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        if ($watcher) {
            $context->logger->log(INFO, "Stopping, removing watcher for fh($fh) ... ") if INFO;
            $context->system->io->remove_selector( $watcher );
        }

        if ($subscriber) {
            $context->logger->log(INFO, "Stopping, removing subscriber, this is an error... ") if INFO;
            $subscriber->send( Yakt::Streams::OnError->new( error => 'Stream stopped early for some reason???') );
        }
    }


    # ... IO Signals

    method can_read :Signal(Yakt::System::Signals::IO::CanRead) ($context, $signal) {
        if ($buffer->read($fh)) {
            $context->logger->log(INFO, "Read bytes from fh($fh)") if INFO;
            if (my @lines = $buffer->flush_buffer) {
                $context->logger->log(INFO, "Got ".(scalar @lines)." lines reading fh($fh)") if INFO;
                $subscriber->send(Yakt::Streams::OnNext->new( sender => $context->self, value => $_ ))
                    foreach @lines;
            }
            else {
                $context->logger->log(INFO, "No lines read from fh($fh)") if INFO;
            }
        }

        if (my $e = $buffer->got_error) {
            $context->logger->log(ERROR, "Got error($e) reading fh($fh)") if ERROR;
            $subscriber->send(Yakt::Streams::OnError->new( sender => $context->self, error => $e ));
            $watcher->is_reading = false;
        }

        if ($buffer->got_eof) {
            $context->logger->log(INFO, "Got EOF reading fh($fh)") if INFO;
            $subscriber->send(Yakt::Streams::OnCompleted->new( sender => $context->self ));
            $watcher->is_reading = false;
        }
    }

    # ... IO Errors

    method got_io_error :Signal(Yakt::System::Signals::IO::GotError) ($context, $signal) {
        # error from select() ???
        # TODO : handle this ...
    }
}
