#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Counter :isa(Yakt::Actor) {
    our @PIDS;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @PIDS => $context->self->pid;
        $context->stop;
    }
}

# Run two separate systems
subtest 'First system' => sub {
    local @Counter::PIDS = ();

    my $sys1 = Yakt::System->new->init(sub ($context) {
        $context->spawn( Yakt::Props->new( class => 'Counter' ) );
        $context->spawn( Yakt::Props->new( class => 'Counter' ) );
    });
    $sys1->loop_until_done;

    # PIDs should be low numbers (system actors + 2 user actors)
    # System has: root(1), sys(2), dead_letters(3), usr(4), then our actors(5,6)
    ok($Counter::PIDS[0] < 10, '... first system has low PIDs');
    is(scalar @Counter::PIDS, 2, '... two actors spawned');
};

subtest 'Second system (independent)' => sub {
    local @Counter::PIDS = ();

    my $sys2 = Yakt::System->new->init(sub ($context) {
        $context->spawn( Yakt::Props->new( class => 'Counter' ) );
    });
    $sys2->loop_until_done;

    # With per-system PIDs, this should also be a low number
    # With global PIDs, this would be higher (7+)
    ok($Counter::PIDS[0] < 10, '... second system also has low PIDs (independent sequence)');
    is(scalar @Counter::PIDS, 1, '... one actor spawned');
};

done_testing;
