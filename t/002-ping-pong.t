#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

class PingPong::Ping      :isa(Acktor::System::Messages::Query) {}
class PingPong::Pong      :isa(Acktor::System::Messages::Query) {}
class PingPong::NewGame   :isa(Acktor::System::Messages::Query) {}
class PingPong::EndGame   :isa(Acktor::System::Messages::Query) {}
class PingPong::GameOver  :isa(Acktor::System::Messages::Command) {}

=pod

Acktor::Protocol->new(PingPong)
    ->accepts(Ping)
    ->accepts(Pong)
    ->accepts(StartGame)
    ->accepts(EndGame)
        ->reply(GameOver)
    ->accepts(GameOver);

=cut

class PingPong :isa(Acktor) {
    use Acktor::Logging;

    field $max_bounces :param = 0;

    field $pings = 0;
    field $pongs = 0;

    our $GAMES_PLAYED  = 0;
    our $GAMES_ENDED   = 0;
    our $TOTAL_BOUNCES = 0;

    # ... start/stop the game

    method new_game :Receive(PingPong::NewGame) ($context, $message) {
        $GAMES_PLAYED++;
        $context->logger->log(INFO, "Got NewGame with ".$message->reply_to) if INFO;
        $message->reply_to->send(PingPong::Ping->new( reply_to => $context->self ));
    }

    method end_game :Receive(PingPong::EndGame) ($context, $message) {
        $GAMES_ENDED++;
        $context->logger->log(INFO, "Got EndGame with ".$message->reply_to) if INFO;
        $message->reply_to->send(PingPong::GameOver->new);
        $context->self->send(PingPong::GameOver->new);
    }

    method game_over :Receive(PingPong::GameOver) ($context, $message) {
        $context->logger->log(INFO, "Got GameOver") if INFO;
        $context->stop;
    }

    ## ... playing the game

    method ping :Receive(PingPong::Ping) ($context, $message) {
        $TOTAL_BOUNCES++;
        $pings++;
        $context->logger->log(INFO, "Pinged(${pings}) checking Bounces(".($pings+$pongs).") MaxBounces($max_bounces)") if INFO;
        if ( $max_bounces && ($pings + $pongs) >= $max_bounces ) {
            $context->logger->log(INFO, "Reached Max($max_bounces) Bounces(".($pings+$pongs).") on Ping, ... ending game") if INFO;
            $message->reply_to->send(PingPong::EndGame->new( reply_to => $context->self ));
        }
        else {
            $message->reply_to->send(PingPong::Pong->new( reply_to => $context->self ));
        }
    }

    method pong :Receive(PingPong::Pong) ($context, $message) {
        $TOTAL_BOUNCES++;
        $pongs++;
        $context->logger->log(INFO, "Ponged(${pongs}) checking Bounces(".($pings+$pongs).") MaxBounces($max_bounces)") if INFO;
        if ( $max_bounces && ($pings + $pongs) >= $max_bounces ) {
            $context->logger->log(INFO, "Reached Max($max_bounces) Bounces(".($pings+$pongs).") on Pong, ... ending game") if INFO;
            $message->reply_to->send(PingPong::EndGame->new( reply_to => $context->self ));
        }
        else {
            $message->reply_to->send(PingPong::Ping->new( reply_to => $context->self ));
        }
    }

}

my $sys = Acktor::System->new->init(sub ($context) {
    my $player1 = $context->spawn(Acktor::Props->new( class => 'PingPong', args => { max_bounces => 5 } ));
    my $player2 = $context->spawn(Acktor::Props->new( class => 'PingPong' ));

    $player1->send(PingPong::NewGame->new( reply_to => $player2 ));

});

$sys->loop_until_done;

is($PingPong::GAMES_PLAYED,  1,  '... got the expected games played');
is($PingPong::GAMES_ENDED,   1,  '... got the expected games ended');
is($PingPong::TOTAL_BOUNCES, 10, '... got the expected total bounces');


done_testing;
