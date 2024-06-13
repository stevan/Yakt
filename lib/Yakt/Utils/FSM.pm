#!perl

use v5.40;
use experimental qw[ class ];
use builtin      qw[ export_lexically ];

use Yakt::Behavior;

package Yakt::Utils::FSM {
    sub import {
        export_lexically(
            '&Behavior' => \&Behavior,
        );
    }

    sub Behavior :prototype($) ($receivers) {
        Yakt::Behavior->new( receivers => $receivers )
    }

}
