#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Supervisor {
    method supervise ($mailbox, $e) { ... }
}

class Actor::Supervisor::Stop {
    method supervise ($mailbox, $) {
        $mailbox->stop;
        return false;
    }
}

class Actor::Supervisor::Restart {
    method supervise ($mailbox, $) {
        $mailbox->restart;
        return false;
    }
}

class Actor::Supervisor::Resume {
    method supervise ($, $) {
        return true;
    }
}

class Actor::Supervisors {
    use constant Stop    => Actor::Supervisor::Stop->new;
    use constant Restart => Actor::Supervisor::Restart->new;
    use constant Resume  => Actor::Supervisor::Resume->new;
}
