#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Streams;

use Yakt::System::Signals::IO;

use Yakt::System::IO::Selector::Stream;
use Yakt::System::IO::Writer::LineBuffered;

class Yakt::IO::Actors::StreamWriter :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $fh :param;

    field $source;

    field $is_completed = false;

    field $watcher;
    field $buffer;

    ADJUST {
        $buffer = Yakt::System::IO::Writer::LineBuffered->new;
    }

    # ... Observer messages

    method on_subscribe :Receive(Yakt::Streams::OnSubscribe) ($context, $message) {
        $context->logger->log(INFO, "->OnSubscribe called" ) if INFO;

        $source = $message->sender;

        $context->logger->log(INFO, "Started, creating watcher for fh($fh) ... ") if INFO;
        $watcher = Yakt::System::IO::Selector::Stream->new( ref => $context->self, fh => $fh );
        $context->system->io->add_selector( $watcher );
    }

    method on_unsubscribe :Receive(Yakt::Streams::OnUnsubscribe) ($context, $message) {
        $context->logger->log(INFO, "->OnUnsubscribe called" ) if INFO;

        $context->logger->log(INFO, "... removing watcher for fh($fh) ... ") if INFO;
        $context->system->io->remove_selector( $watcher );
        $watcher = undef;
        $source  = undef;

        $context->stop;
    }

    method on_next :Receive(Yakt::Streams::OnNext) ($context, $message) {
        $context->logger->log(INFO, "Got ->OnNext: ",$message->value) if INFO;
        $buffer->buffered_write($message->value);
        $watcher->is_writing = true;
    }

    method on_completed :Receive(Yakt::Streams::OnCompleted) ($context, $message) {
        $context->logger->log(INFO, "->OnCompleted called" ) if INFO;
        # we might be in one of two possible
        # states, first, the watcher might
        # be done writing, in that case
        if (!$watcher->is_writing) {
            # we unsubscribe from the source
            $source->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
        } else {
            # otherwise, we mark ourselves
            # as completed, so that we can
            # handle the unsubscribe when
            # everything is done
            $is_completed = true;
        }
    }

    method on_error :Receive(Yakt::Streams::OnError) ($context, $message) {
        $context->logger->log(INFO, "->OnError called" ) if INFO;
        $context->logger->log(ERROR, "Got error: ",$message->error) if ERROR;

        $source->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
        $watcher->is_writing = false;
    }

    # ... Signals

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        $context->logger->log(INFO, "Stopping ..." ) if INFO;

        if ($watcher) {
            $context->logger->log(INFO, "Stopping, removing watcher for fh($fh) ... ") if INFO;
            $context->system->io->remove_selector( $watcher );
        }

        if ($source) {
            $source->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
            # FIXME: the OnUnsubscribe response will end up in the dead letter queue
            # this is not ideal, so we should fix it ... even though this is an exception
            # case, it is neccessary to fixup the flows
        }
    }


    # ... IO Signals

    method can_write :Signal(Yakt::System::Signals::IO::CanWrite) ($context, $signal) {
        $context->logger->log(INFO, "Can Write!!!!!" ) if INFO;
        $watcher->is_writing = $buffer->write($fh);

        # notify that we are done writing if we are completed
        if ($is_completed && !$watcher->is_writing) {
            $source->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
        }
    }

    # ... IO Errors

    method got_io_error :Signal(Yakt::System::Signals::IO::GotError) ($context, $signal) {
        # error from select() ???
        # TODO : handle this ...
    }
}
