#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::OnCompleted :isa(Yakt::Message) {}
