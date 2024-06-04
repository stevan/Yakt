#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;
use Acktor::Props;
use Acktor::System::Signals;
use Acktor::System::Actors::System;
use Acktor::System::Actors::Users;

class Acktor::System::Actors::Root :isa(Acktor) {
    use Acktor::Logging;

    field $init :param;

    field $system;
    field $users;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method signal ($context, $signal) {
        if ($signal isa Acktor::System::Signals::Started) {
            $logger->alert("STARTING SETUP") if DEBUG;
            $logger->log(INTERNALS, sprintf 'Started %s' => $context->self ) if INTERNALS;

            $system = $context->spawn( Acktor::Props->new(
                class => 'Acktor::System::Actors::System',
                alias => '//sys'
            ));

        } elsif ($signal isa Acktor::System::Signals::Ready) {
            if ( refaddr $signal->ref == refaddr $system ) {
                $logger->log(INTERNALS, sprintf 'System Started for(%s) starting User' => $context->self ) if INTERNALS;

                $users = $context->spawn( Acktor::Props->new(
                    class => 'Acktor::System::Actors::Users',
                    alias => '//usr',
                ));
            } elsif ( refaddr $signal->ref == refaddr $users ) {
                $logger->log(INTERNALS, sprintf 'Users Started for(%s) calling Init' => $context->self ) if INTERNALS;
                $logger->alert("FINISHING SETUP") if DEBUG;
                $logger->alert("STARTING INITIALIZATION") if DEBUG;
                $logger->log(INTERNALS, sprintf 'Got Ready from(%s) for(%s)' => $signal->ref, $context->self ) if INTERNALS;
                try {
                    $logger->log(INTERNALS, "Running init callback for User Context(".$users->context.")" ) if INTERNALS;
                    $init->($users->context);
                } catch ($e) {
                    $logger->log(ERROR, "!!!!!! Error running init callback for $context with ($e)" ) if ERROR;
                }
                $logger->alert("FINISHING INITIALIZATION") if DEBUG;
            }
        } elsif ($signal isa Acktor::System::Signals::Stopping) {
            $logger->alert("ENTERING SHUTDOWN") if DEBUG;
            $logger->log(INTERNALS, sprintf 'Stopping %s' => $context->self ) if INTERNALS;
        } elsif ($signal isa Acktor::System::Signals::Stopped) {
            $logger->alert("EXITING SHUTDOWN") if DEBUG;
            $logger->log(INTERNALS, sprintf 'Stopped %s' => $context->self ) if INTERNALS;
        }
    }
}
