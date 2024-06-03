#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Acktor::Supervisors {
    use Acktor::Supervisors::Supervisor;
    use Acktor::Supervisors::Restart;
    use Acktor::Supervisors::Retry;
    use Acktor::Supervisors::Resume;
    use Acktor::Supervisors::Stop;
}

