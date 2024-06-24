#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::OnSuccess :isa(Yakt::Message) {
    field $value :param :reader;
}
