#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::Props';
use ok 'Yakt::Actor';

class TestActor :isa(Yakt::Actor) {
    field $name :param = 'default';
    field $count :param = 0;

    method name { $name }
    method count { $count }
}

subtest 'new_actor creates instance of correct class' => sub {
    my $props = Yakt::Props->new( class => 'TestActor' );
    my $actor = $props->new_actor;

    isa_ok($actor, 'TestActor', '... creates correct class');
    isa_ok($actor, 'Yakt::Actor', '... inherits from Yakt::Actor');
};

subtest 'new_actor passes args to constructor' => sub {
    my $props = Yakt::Props->new(
        class => 'TestActor',
        args  => { name => 'custom', count => 42 }
    );
    my $actor = $props->new_actor;

    is($actor->name, 'custom', '... name arg passed correctly');
    is($actor->count, 42, '... count arg passed correctly');
};

subtest 'new_actor with default args' => sub {
    my $props = Yakt::Props->new( class => 'TestActor' );
    my $actor = $props->new_actor;

    is($actor->name, 'default', '... uses default name');
    is($actor->count, 0, '... uses default count');
};

done_testing;
