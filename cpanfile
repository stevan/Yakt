
requires 'perl'             => '5.040';
requires 'Term::ReadKey'    => 0;

on 'test' => sub {
    requires 'Test::More'      => 0;
    requires 'HTTP::Message'   => 0;
    requires 'IO::Socket::SSL' => 0;
};
