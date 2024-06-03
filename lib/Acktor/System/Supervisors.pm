#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

package Acktor::System::Supervisors {
    use Acktor::System::Supervisors::Supervisor;
    use Acktor::System::Supervisors::Restart;
    use Acktor::System::Supervisors::Retry;
    use Acktor::System::Supervisors::Resume;
    use Acktor::System::Supervisors::Stop;
}

