#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Behavior;

use Yakt::Streams::OnSuccess;
use Yakt::Streams::OnError;
use Yakt::Streams::OnSubscribe;
use Yakt::Streams::OnUnsubscribe;

class Yakt::Streams::Actors::Observer::Single :isa(Yakt::Actor) {
    use Yakt::Logging;

    method on_subscribe   ($, $) {}
    method on_unsubscribe ($, $) {}

    method on_success;
    method on_error;

    my %BEHAVIORS_FOR;
    sub behavior_for ($pkg) {
        $BEHAVIORS_FOR{$pkg} //= Yakt::Behavior->new(
            receivers => {
                Yakt::Streams::OnSubscribe::   => $pkg->can('on_subscribe'),
                Yakt::Streams::OnUnsubscribe:: => $pkg->can('on_unsubscribe'),
                Yakt::Streams::OnSuccess::     => $pkg->can('on_success'),
                Yakt::Streams::OnError::       => $pkg->can('on_error'),
            }
        );
    }
}
