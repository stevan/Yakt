#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Acktor::System';

class Bar {}

class Foo :isa(Acktor) {
    use Acktor::Logging;

    field $depth :param = 1;
    field $max   :param = 4;

    our (
        $FORCED_RESTART,
        $STARTED,
        $RESTARTED,
        $STOPPING,
        $STOPPED
    );

    method hello :Receive(Bar) ($context, $message) {
        $context->logger->log(INFO, "HELLO JOE! => { Actor($self), $context, message($message) }" ) if INFO;
        $FORCED_RESTART++;
        die "Going to Restart!"
    }

    method on_start :Signal(Acktor::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        $context->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;
        if ( $depth <= $max ) {
            $context->spawn(Acktor::Props->new(
                class => 'Foo',
                args => {
                    depth => $depth + 1,
                    max   => $max
                }
            ));
        }
        else {
            # FIXME - do this better, its clumsy
            # find the topmost Foo
            my $x = $context->self;
            do {
                $x = $x->context->parent;
            } while $x->context->parent
                 && $x->context->parent->context->props->class eq 'Foo';

            # and stop it
            if ($FORCED_RESTART) {
                $x->context->stop;
            }
            else {
                $x->send( Bar->new );
            }
        }
    }

    method on_stopping :Signal(Acktor::System::Signals::Stopping) ($context, $signal) {
        $STOPPING++;
        $context->logger->log( INFO, sprintf 'Stopping %s' => $context->self ) if INFO
    }

    method on_restarting :Signal(Acktor::System::Signals::Restarting) ($context, $signal) {
        $RESTARTED++;
        $context->logger->log( INFO, sprintf 'Restarting %s' => $context->self ) if INFO
    }

    method on_stopped :Signal(Acktor::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
        $context->logger->log( INFO, sprintf 'Stopped %s' => $context->self ) if INFO
    }

}

my $sys = Acktor::System->new->init(sub ($context) {
    $context->spawn(Acktor::Props->new(
        class      => 'Foo',
        supervisor => Acktor::System::Supervisors::Restart->new
    ));
});

$sys->loop_until_done;

is($Foo::FORCED_RESTART, 1, '... got the expected forced restarts');
is($Foo::RESTARTED,      1, '... got the expected restarted');
is($Foo::STARTED,       10, '... got the expected started');
is($Foo::STOPPING,       9, '... got the expected stopping');
is($Foo::STOPPED,        9, '... got the expected stopped');

done_testing;

