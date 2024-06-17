#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::OnUnsubscribe :isa(Yakt::Message) {}
