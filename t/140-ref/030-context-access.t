#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class ContextCheckActor :isa(Yakt::Actor) {
    our $REF_HAS_CONTEXT = 0;
    our $CONTEXT_MATCHES = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        my $ref = $context->self;

        # Check ref has context
        $REF_HAS_CONTEXT = defined $ref->context ? 1 : 0;

        # Check context self returns the same ref
        $CONTEXT_MATCHES = (refaddr($ref->context->self) == refaddr($ref)) ? 1 : 0;

        $context->stop;
    }
}

subtest 'Ref provides access to context' => sub {
    $ContextCheckActor::REF_HAS_CONTEXT = 0;
    $ContextCheckActor::CONTEXT_MATCHES = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'ContextCheckActor' ));
    });

    $sys->loop_until_done;

    ok($ContextCheckActor::REF_HAS_CONTEXT, '... ref has context');
    ok($ContextCheckActor::CONTEXT_MATCHES, '... context->self returns same ref');
};

done_testing;
