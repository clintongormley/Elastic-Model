#!/usr/bin/perl

use strict;
use warnings;

our $test_class = 'TypeTest::Structured';
our @mapping    = (
    'tuple' => {
        dynamic => "strict",
        properties =>
            { "0" => { type => "string" }, "1" => { type => "long" } },
        type => "object",
    },
    'dict' => {
        dynamic    => "strict",
        properties => {
            "str" => { type => "string" },
            "int" => { type => "long" }
        },
        type => "object",
    },
    'map'      => { type => 'object', enabled => 0 },
    'optional' => { type => 'long' },
    'combo'    => {
        type       => "object",
        dynamic    => "strict",
        properties => {
            dict => {
                dynamic    => "strict",
                properties => { Int => { type => "string" } },
                type       => "object",
            },
            map => { type => 'object', enabled => 0 },
            str => { type => "string" },
        },
    }
);

do 't/10_typemaps/test_mapping.pl' or die $!;

1;
