#!perl

use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;
use Elastic::Model::SearchBuilder;

my $a = Elastic::Model::SearchBuilder->new;

eq_or_diff $a->query( { k => { '=' => { query => 0 } } } ),
    { query => { text => { k => { query => 0 } } } },
    'False string hash_param';

throws_ok { $a->query( { k => { '=' => { query => undef } } } ) }
qr/missing required param/, 'Undefined hash_param';

done_testing;
