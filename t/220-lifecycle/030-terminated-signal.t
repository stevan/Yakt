#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class StopChild :isa(Yakt::Message) {}

class ChildToWatch :isa(Yakt::Actor) {
    method on_stop :Receive(StopChild) ($context, $message) {
        $context->stop;
    }
}

class ParentWithTerminated :isa(Yakt::Actor) {
    our @TERMINATED_CHILDREN;
    our $CHILD_COUNT = 0;

    field @children;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @children => $context->spawn(Yakt::Props->new( class => 'ChildToWatch' ));
        push @children => $context->spawn(Yakt::Props->new( class => 'ChildToWatch' ));

        # Stop first child
        $children[0]->send(StopChild->new);
    }

    method on_terminated :Signal(Yakt::System::Signals::Terminated) ($context, $signal) {
        push @TERMINATED_CHILDREN => $signal->ref->pid;
        $CHILD_COUNT++;

        # When first child terminates, stop second
        if ($CHILD_COUNT == 1) {
            $children[1]->send(StopChild->new);
        }
        # When both done, stop self
        elsif ($CHILD_COUNT == 2) {
            $context->stop;
        }
    }
}

subtest 'Parent receives Terminated signal for each child' => sub {
    @ParentWithTerminated::TERMINATED_CHILDREN = ();
    $ParentWithTerminated::CHILD_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'ParentWithTerminated' ));
    });

    $sys->loop_until_done;

    is($ParentWithTerminated::CHILD_COUNT, 2, '... received Terminated for both children');
    is(scalar @ParentWithTerminated::TERMINATED_CHILDREN, 2, '... collected both child PIDs');
};

done_testing;
