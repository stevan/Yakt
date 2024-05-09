#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Supervisor {
    use constant RESUME => 1;
    use constant RETRY  => 2;
    use constant HALT   => 3;

    method supervise ($mailbox, $e, $msg) { ... }
}

class Actor::Supervisor::Stop :isa(Actor::Supervisor) {
    method supervise ($mailbox, $, $) {
        $mailbox->stop;
        return $self->HALT;
    }
}

class Actor::Supervisor::Restart :isa(Actor::Supervisor) {
    method supervise ($mailbox, $, $) {
        $mailbox->restart;
        return $self->HALT;
    }
}

class Actor::Supervisor::Resume :isa(Actor::Supervisor) {
    method supervise ($, $, $) {
        return $self->RESUME;
    }
}

class Actor::Supervisor::Retry :isa(Actor::Supervisor) {
    method supervise ($, $, $) {
        return $self->RETRY;
    }
}

class Actor::Supervisors {
    use constant Stop    => Actor::Supervisor::Stop->new;
    use constant Restart => Actor::Supervisor::Restart->new;
    use constant Resume  => Actor::Supervisor::Resume->new;
    use constant Retry   => Actor::Supervisor::Retry->new;
}
