#!perl

use v5.40;
use experimental qw[ class ];

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

    method signal ($context, $signal) {
        my $logger = $context->logger;

        if ($signal isa Acktor::System::Signals::Started) {
            $logger->notification("STARTING SETUP") if DEBUG;
            $logger->log(INTERNALS, sprintf 'Started %s' => $context->self ) if INTERNALS;

            $system = $context->spawn( Acktor::Props->new(
                class => 'Acktor::System::Actors::System',
                alias => '//sys'
            ));

        } elsif ($signal isa Acktor::System::Signals::Ready) {
                $logger->log(INTERNALS, sprintf 'Got Ready from(%s) for(%s)' => $signal->ref, $context->self ) if INTERNALS;
            if ( refaddr $signal->ref == refaddr $system ) {
                $logger->log(INTERNALS, sprintf 'System is Started for(%s) ... now starting User' => $context->self ) if INTERNALS;

                $users = $context->spawn( Acktor::Props->new(
                    class => 'Acktor::System::Actors::Users',
                    alias => '//usr',
                ));
            } elsif ( refaddr $signal->ref == refaddr $users ) {
                $logger->log(INTERNALS, sprintf 'Users is Started for(%s) ... now calling &init' => $context->self ) if INTERNALS;
                $logger->notification("FINISHING SETUP") if DEBUG;
                $logger->log(DEBUG, "System is ready, starting initialization...") if DEBUG;
                try {
                    $logger->notification("STARTING INITIALIZATION") if DEBUG;
                    $init->($users->context);
                    $logger->notification("FINISHING INITIALIZATION") if DEBUG;
                } catch ($e) {
                    $logger->log(ERROR, "!!!!!! Error running init callback for $context with ($e)" ) if ERROR;
                }
            }
        } elsif ($signal isa Acktor::System::Signals::Stopping) {
            $logger->log(INTERNALS, sprintf 'Stopping %s' => $context->self ) if INTERNALS;
        } elsif ($signal isa Acktor::System::Signals::Stopped) {
            $logger->notification("EXITING SHUTDOWN") if DEBUG;
            $logger->log(INTERNALS, sprintf 'Stopped %s' => $context->self ) if INTERNALS;
        } elsif ($signal isa Acktor::System::Signals::Terminated) {
            my $ref = $signal->ref;
            $logger->log(INTERNALS, "Got Terminated from $ref") if INTERNALS;
            if (refaddr $ref == refaddr $users) {
                $logger->notification("ENTERING SHUTDOWN") if DEBUG;
                $logger->log(INTERNALS, sprintf 'Users is Stopped, ... now shutting down %s' => $system ) if INTERNALS;
                $system->context->stop;
            } elsif (refaddr $ref == refaddr $system) {
                # TODO:
                # detect the case where it is system shutting
                # down before users is full shut down, but
                # this shold not really happen, so we can punt
                # on it for now.
                $logger->log(INTERNALS, sprintf 'System is Stopped, ... now shutting down %s' => $context->self ) if INTERNALS;
                $context->stop;
            }
        }
    }
}
