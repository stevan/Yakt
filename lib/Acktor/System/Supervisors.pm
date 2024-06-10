#!perl

use v5.40;
use experimental qw[ class ];

package Acktor::System::Supervisors {
    use Acktor::System::Supervisors::Supervisor;
    use Acktor::System::Supervisors::Restart;
    use Acktor::System::Supervisors::Retry;
    use Acktor::System::Supervisors::Resume;
    use Acktor::System::Supervisors::Stop;
}

