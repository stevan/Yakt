#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Acktor::System';

class RandomTree :isa(Acktor::Actor) {
    use Acktor::Logging;

    use constant MAX_DEPTH => 10;

    field $root  :param = undef;
    field $depth :param = 0;

    our $MESSAGED   = 0;
    our $STARTED    = 0;
    our $STOPPING   = 0;
    our $STOPPED    = 0;

    # $context->logger->bubble( 'Actor Tree', [ $context->system->print_actor_tree($context->self) ] ) if INFO;

    method on_start :Signal(Acktor::System::Signals::Started) ($context, $signal) {
        $STARTED++;
        $context->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;

        if ($depth < MAX_DEPTH) {
            $context->spawn(Acktor::Props->new(
                class => 'RandomTree',
                args  => {
                    root  => $root // $context->self,
                    depth => $depth + 1,
                }
            )) foreach 0 .. int(rand(3));
        }
        else {
            if ($root->context->is_alive) {
                $root->context->stop;
            }
        }
    }

    method on_stopping :Signal(Acktor::System::Signals::Stopping) ($context, $signal) {
        $STOPPING++;
        if ( !$root ) {
            $context->logger->log( WARN, 'Got Stop Signal for '.$context ) if WARN;
        }
        #$context->logger->log( INFO, sprintf 'Stopping %s' => $context->self ) if INFO
    }

    method on_stopped :Signal(Acktor::System::Signals::Stopped) ($context, $signal) {
        $STOPPED++;
        #$context->logger->log( INFO, sprintf 'Stopped %s' => $context->self ) if INFO
    }
}

my $sys = Acktor::System->new->init(sub ($context) {
    my $t = $context->spawn( Acktor::Props->new( class => 'RandomTree' ) );
});

$sys->loop_until_done;

done_testing;

