#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

class Query {
    field $reply_to :param;
    method reply_to { $reply_to }
}

class Command {}

class PingPong::Ping     :isa(Query) {}
class PingPong::Pong     :isa(Query) {}

class PingPong::Reset    :isa(Command) {}

class PingPong::NewGame   :isa(Query)   {}
class PingPong::EndGame   :isa(Query)   {}
class PingPong::GameOver  :isa(Command) {}

=pod

Acktor::Protocol->new(PingPong)
    ->accepts(Ping)
    ->accepts(Pong)
    ->accepts(StartGame)
    ->accepts(EndGame)
        ->reply(GameOver)
    ->accepts(Reset)
    ->accepts(GameOver);

=cut

class PingPong :isa(Acktor) {
    use Acktor::Logging;

    field $max_bounces :param = 0;

    field $pings = 0;
    field $pongs = 0;

    # ... reset the machine (turn it on and off again)

    method reset :Receive(PingPong::Reset) ($context, $message) {
        $context->logger->log(INFO, "Got reset!") if INFO;
        $context->restart;
    }

    # ... start/stop the game

    method new_game :Receive(PingPong::NewGame) ($context, $message) {
        $context->logger->log(INFO, "Got NewGame with ".$message->reply_to) if INFO;
        $message->reply_to->send(PingPong::Ping->new( reply_to => $context->self ));
    }

    method end_game :Receive(PingPong::EndGame) ($context, $message) {
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


done_testing;
