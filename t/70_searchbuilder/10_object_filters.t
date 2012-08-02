#!perl

use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;
use Elastic::Model::SearchBuilder;

use lib 't/lib';

use_ok 'MyApp' || print 'Bail out';

my $model = new_ok( 'MyApp', [], 'Model' );
isa_ok my $domain = $model->domain('myapp'), 'Elastic::Model::Domain';

isa_ok
    my $user = $domain->new_doc( user => { id => 1, name => 'X' } ),
    'MyApp::User',
    'User';

isa_ok
    my $uid = $user->uid,
    'Elastic::Model::UID',
    'UID';

my @objs = ( $user, $uid );

my $a = Elastic::Model::SearchBuilder->new;

test_filters(
    'SCALAR',

    'Object', $user,
    {   and => [
            { term => { 'uid.index' => 'myapp' } },
            { term => { 'uid.type'  => 'user' } },
            { term => { 'uid.id'    => 1 } },
        ]
    },

    'UID', $uid,
    {   and => [
            { term => { 'uid.index' => 'myapp' } },
            { term => { 'uid.type'  => 'user' } },
            { term => { 'uid.id'    => 1 } },
        ]
    },
);

test_filters(
    'HASHREF - no key',
    'Object',
    { '' => $user },
    {   and => [
            { term => { 'uid.index' => 'myapp' } },
            { term => { 'uid.type'  => 'user' } },
            { term => { 'uid.id'    => 1 } },
        ]
    },

    'UID',
    { '' => $uid },
    {   and => [
            { term => { 'uid.index' => 'myapp' } },
            { term => { 'uid.type'  => 'user' } },
            { term => { 'uid.id'    => 1 } },
        ]
    },

);

test_filters(
    'HASHREF - key',
    'Object',
    { 'user' => $user },
    {   and => [
            { term => { 'user.uid.index' => 'myapp' } },
            { term => { 'user.uid.type'  => 'user' } },
            { term => { 'user.uid.id'    => 1 } },
        ]
    },

    'UID',
    { 'user' => $uid },
    {   and => [
            { term => { 'user.uid.index' => 'myapp' } },
            { term => { 'user.uid.type'  => 'user' } },
            { term => { 'user.uid.id'    => 1 } },
        ]
    },

);

test_filters(
    '= op', 'Object',
    { 'user' => { '=' => $user } },
    {   and => [
            { term => { 'user.uid.index' => 'myapp' } },
            { term => { 'user.uid.type'  => 'user' } },
            { term => { 'user.uid.id'    => 1 } },
        ]
    },

    'UID',
    { 'user' => { '=' => $uid } },
    {   and => [
            { term => { 'user.uid.index' => 'myapp' } },
            { term => { 'user.uid.type'  => 'user' } },
            { term => { 'user.uid.id'    => 1 } },
        ]
    },

);

test_filters(
    '!= op', 'Object',
    { 'user' => { '!=' => $user } },
    {   not => {
            filter => {
                and => [
                    { term => { 'user.uid.index' => 'myapp' } },
                    { term => { 'user.uid.type'  => 'user' } },
                    { term => { 'user.uid.id'    => 1 } },
                ]
            }
        }
    },
    'UID',
    { 'user' => { '!=' => $uid } },
    {   not => {
            filter => {
                and => [
                    { term => { 'user.uid.index' => 'myapp' } },
                    { term => { 'user.uid.type'  => 'user' } },
                    { term => { 'user.uid.id'    => 1 } },
                ]
            }
        }
    },
);

test_filters(
    'ARRAYREF',
    'Objects',
    { 'user' => \@objs },
    {   or => [ {
                and => [
                    { term => { 'user.uid.index' => 'myapp' } },
                    { term => { 'user.uid.type'  => 'user' } },
                    { term => { 'user.uid.id'    => 1 } },
                ]
            },
            {   and => [
                    { term => { 'user.uid.index' => 'myapp' } },
                    { term => { 'user.uid.type'  => 'user' } },
                    { term => { 'user.uid.id'    => 1 } },
                ]
            },
        ]
    },

    '= Objects',
    { 'user' => { '=' => \@objs } },
    {   or => [ {
                and => [
                    { term => { 'user.uid.index' => 'myapp' } },
                    { term => { 'user.uid.type'  => 'user' } },
                    { term => { 'user.uid.id'    => 1 } },
                ]
            },
            {   and => [
                    { term => { 'user.uid.index' => 'myapp' } },
                    { term => { 'user.uid.type'  => 'user' } },
                    { term => { 'user.uid.id'    => 1 } },
                ]
            },
        ]
    },
    '!= Objects',
    { 'user' => { '!=' => \@objs } },
    {   not => {
            filter => {
                or => [ {
                        and => [
                            { term => { 'user.uid.index' => 'myapp' } },
                            { term => { 'user.uid.type'  => 'user' } },
                            { term => { 'user.uid.id'    => 1 } },
                        ]
                    },
                    {   and => [
                            { term => { 'user.uid.index' => 'myapp' } },
                            { term => { 'user.uid.type'  => 'user' } },
                            { term => { 'user.uid.id'    => 1 } },
                        ]
                    },
                ]
            }
        }
    }

);

done_testing();

#===================================
sub test_filters {
#===================================
    note "\n" . shift();
    while (@_) {
        my $name = shift;
        my $in   = shift;
        my $out  = shift;
        if ( ref $out eq 'Regexp' ) {
            throws_ok { $a->filter($in) } $out, $name;
        }
        else {
            eval {
                eq_or_diff scalar $a->filter($in), { filter => $out }, $name;
                1;
            }
                or die "*** FAILED TEST $name:***\n$@";
        }
    }
}
