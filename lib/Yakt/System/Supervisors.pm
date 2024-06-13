#!perl

use v5.40;
use experimental qw[ class ];

package Yakt::System::Supervisors {
    use Yakt::System::Supervisors::Supervisor;
    use Yakt::System::Supervisors::Restart;
    use Yakt::System::Supervisors::Retry;
    use Yakt::System::Supervisors::Resume;
    use Yakt::System::Supervisors::Stop;
}

