#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class ChildCreated :isa(Yakt::Message) {}

class ChildActor :isa(Yakt::Actor) {
    our $INSTANCE_COUNT = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $INSTANCE_COUNT++;
    }
}

class ParentActor :isa(Yakt::Actor) {
    our $CHILD_REF;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $CHILD_REF = $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
        $context->stop;
    }
}

subtest 'spawn creates child actor and returns ref' => sub {
    $ChildActor::INSTANCE_COUNT = 0;
    $ParentActor::CHILD_REF = undef;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'ParentActor' ));
    });

    $sys->loop_until_done;

    is($ChildActor::INSTANCE_COUNT, 1, '... child actor was created');
    ok(defined $ParentActor::CHILD_REF, '... spawn returned a ref');
    isa_ok($ParentActor::CHILD_REF, 'Yakt::Ref', '... ref is correct type');
};

class MultiChildParent :isa(Yakt::Actor) {
    our @CHILDREN;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @CHILDREN => $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
        push @CHILDREN => $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
        push @CHILDREN => $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
        $context->stop;
    }
}

subtest 'spawn multiple children' => sub {
    $ChildActor::INSTANCE_COUNT = 0;
    @MultiChildParent::CHILDREN = ();

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'MultiChildParent' ));
    });

    $sys->loop_until_done;

    is($ChildActor::INSTANCE_COUNT, 3, '... three child actors were created');
    is(scalar @MultiChildParent::CHILDREN, 3, '... three refs returned');
};

subtest 'children method returns spawned children' => sub {
    my $children_count;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'ChildActor' ));
        $context->spawn(Yakt::Props->new( class => 'ChildActor' ));

        # Schedule a check after children are spawned
        $context->schedule(
            after    => 0.01,
            callback => sub {
                $children_count = scalar $context->children;
                $context->stop;
            }
        );
    });

    $sys->loop_until_done;

    is($children_count, 2, '... context->children returns correct count');
};

done_testing;
