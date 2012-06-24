#!/usr/bin/perl

use strict;
use warnings;

our $test_class = 'FieldTest::Binary';

our @mapping = (
    'basic' => { type => 'binary' },

    'options' => {
        index_name => "foo",
        store      => "yes",
        type       => "binary",
    },
    multi   => qr/doesn't understand 'multi'/,
    bad_opt => qr/doesn't understand 'omit_norms'/,

);

do 't/10_typemaps/test_field.pl' or die $!;

1;
