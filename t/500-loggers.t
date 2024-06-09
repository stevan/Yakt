#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

use Acktor::Logging;

class Logging::Message {
    use Time::HiRes;

    field $timestamp :reader;

    ADJUST {
        $timestamp = Time::HiRes::time;
    }
}

class Logging::Bubble :isa(Logging::Message) {
    field $label    :param :reader;
    field $contents :param :reader;
}

class Logging::Line :isa(Logging::Message) {
    field $label      :param :reader;
    field $additional :param :reader = undef;
}

class Logging::Notification :isa(Logging::Line) {}
class Logging::Alert        :isa(Logging::Line) {}
class Logging::Header       :isa(Logging::Line) {}

class Logging::Log :isa(Logging::Message) {
    field $level   :param :reader;
    field $message :param :reader;
}

class AsyncLogger :isa(Acktor) {

    field $target :param :reader;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger($target);
    }

    method log :Receive(Logging::Log) ($context, $log) {
        $logger->log( $log->level, ("(TIMESTAMP: ",$log->timestamp,") "), $log->message->@* );
    }

    method line :Receive(Logging::Line) ($context, $log) {
        $logger->line( $log->label, $log->additional // $log->timestamp );
    }

}

class NewLogger {
    field $ref :param;

    method log ($level, @msg) {
        $ref->send( Logging::Log->new( level => $level, message => \@msg ) );
    }

    method line ($label, $additional=undef) {
        $ref->send( Logging::Line->new( label => $label, additional => $additional ) );
    }
}

class Echo::Echo {
    field $echo :param :reader;
}

class Echo :isa(Acktor) {
    use Acktor::Logging;

    field $logger;

    method on_start :Signal(Acktor::System::Signals::Started) ($context, $) {
        $logger = NewLogger->new(
            ref => $context->spawn( Acktor::Props->new(
                class => 'AsyncLogger',
                args  => { target => $context->self },
            ))
        );

        $logger->line('starting');
    }

    method on_stopping :Signal(Acktor::System::Signals::Stopping) ($context, $) {
        $logger->line('stopping');
    }

    method on_stopped :Signal(Acktor::System::Signals::Stopped) ($context, $) {
        $logger->line('stopped');
    }

    method echo :Receive(Echo::Echo) ($context, $message) {
        my $echo = $message->echo;
        $logger->log( INFO, "Got Echo(${echo})");
        $logger->line('... waiting a second');
        $context->schedule( after => 1, callback => sub {
            $logger->log( INFO, "Got Echo(${echo}) (Echo)");
            $logger->line('... waiting a second');
            $context->schedule( after => 1, callback => sub {
                $logger->log( INFO, "Got Echo(${echo}) (Echo) (echo)");
                $logger->line('... waiting a second');
                $context->schedule( after => 1, callback => sub {
                    $logger->log( INFO, "Got Echo(${echo}) (Echo) (echo) (...) ");
                    $context->stop;
                });
            });
        });

    }

}



my $sys = Acktor::System->new->init(sub ($context) {
    my $echo = $context->spawn( Acktor::Props->new( class => 'Echo' ) );

    $echo->send(Echo::Echo->new( echo => 'Hello' ));

});

$sys->loop_until_done;


done_testing;

