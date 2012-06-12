#!/usr/bin/perl

use strict;
use warnings;
use Test::More 0.96;
use Test::Moose;
use Test::Deep;

use lib 't/lib';

do 'es.pl';
our $es = get_es();

$es->delete_index( index => 'myapp3', ignore_missing => 1 );

wait_for_es();

use_ok 'MyApp' || print 'Bail out';

my $model = new_ok( 'MyApp', [ es => $es ], 'Model' );
ok my $ns = $model->namespace('myapp'), 'Got ns';

isa_ok my $index = $ns->index('myapp3'), 'Elastic::Model::Index',
    'Index myapp3';

is $index->name, 'myapp3', 'Index name is myapp3';

## Create index ##

ok $index->create, 'Create index myapp3';
ok $index->exists, 'Index myapp3 exists';

## Delete index ##
ok $index->delete, 'Delete index';
ok !$index->exists, 'Index deleted';

## Create advanced ##
ok $index->create(
    settings => { refresh_interval => '10s' },
    types    => ['user']
    ),
    'Create index with settings and types';

is $es->index_settings( index => 'myapp3' )
    ->{myapp3}{settings}{"index.refresh_interval"},
    '10s', 'Settings OK';

isa_ok my $mapping = $es->mapping( index => 'myapp3' )->{myapp3}, 'HASH',
    'Mapping';

ok $mapping->{user}, 'Has user mapping';
ok !$mapping->{post}, 'No post mapping';
ok $index->delete, 'Delete index';

done_testing;

__END__
