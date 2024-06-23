#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';


subtest '... checking the init' => sub {
    my $COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $COUNT++;
    });

    $sys->loop_until_done;

    is($COUNT, 1, '... got the expected count');
};

subtest '... checking the init' => sub {
    my $COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        die;
    });

    $sys->loop_until_done;

    is($COUNT, 0, '... got the expected count after die-ing in init');
};

done_testing;

