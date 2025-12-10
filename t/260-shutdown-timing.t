#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Msg {}

# Parent that spawns children which do cleanup work on Stopping
class Parent :isa(Yakt::Actor) {
    our @EVENTS;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @EVENTS => 'parent:started';

        # Spawn several children
        for my $i (1..3) {
            $context->spawn( Yakt::Props->new(
                class => 'SlowChild',
                args  => { id => $i }
            ));
        }

        # Schedule stop after children are spawned
        $context->schedule( after => 0.01, callback => sub {
            push @EVENTS => 'parent:requesting_stop';
            $context->stop;
        });
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        push @EVENTS => 'parent:stopping';
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        push @EVENTS => 'parent:stopped';
    }
}

class SlowChild :isa(Yakt::Actor) {
    field $id :param;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @Parent::EVENTS => "child$id:started";
    }

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        push @Parent::EVENTS => "child$id:stopping";
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        push @Parent::EVENTS => "child$id:stopped";
    }
}

@Parent::EVENTS = ();

my $sys = Yakt::System->new->init(sub ($context) {
    $context->spawn( Yakt::Props->new( class => 'Parent' ) );
});

$sys->loop_until_done;

# Verify all children stopped before parent
my $parent_stopped_idx = 0;
my @child_stopped_idxs;

for my $i (0..$#Parent::EVENTS) {
    if ($Parent::EVENTS[$i] eq 'parent:stopped') {
        $parent_stopped_idx = $i;
    }
    if ($Parent::EVENTS[$i] =~ /child\d:stopped/) {
        push @child_stopped_idxs => $i;
    }
}

is(scalar @child_stopped_idxs, 3, '... all 3 children stopped');

my $all_before = 1;
for my $idx (@child_stopped_idxs) {
    $all_before = 0 if $idx >= $parent_stopped_idx;
}
ok($all_before, '... all children stopped before parent');

done_testing;
