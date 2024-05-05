#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Ref {
    field $address :param;
    field $props   :param;
    field $context :param;

    ADJUST { $context->assign_self( $self ) }

    method props   { $props   }
    method address { $address }
    method context { $context }

    method send ($message) {
        $context->send_to( $self, $message );
        return;
    }
}
