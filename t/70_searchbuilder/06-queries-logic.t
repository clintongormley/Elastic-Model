#!perl

use strict;
use warnings;

use Test::More;
use Test::Differences;
use Test::Exception;
use Elastic::Model::SearchBuilder;

my $a = Elastic::Model::SearchBuilder->new;

test_queries(
    'EMPTY AND|OR|NOT',

    '-and',
    { k => 1, -and => [] },
    { text => { k => 1 } },

    '-or',
    { k => 1, -or => [] },
    { text => { k => 1 } },

    '-not',
    { k => 1, -not => [] },
    { text => { k => 1 } },
);

test_queries(
    'SCALAR',
    '-and scalar',
    { -and => 1 },
    qr/little sense/,

    '-or scalar',
    { -or => 1 },
    qr/little sense/,

    '-not scalar',
    { -not => 1 },
    qr/little sense/
);

test_queries(
    'UNDEF',
    '-and undef',
    { -and => undef },
    qr/undef not supported/,

    '-or undef',
    { -or => undef },
    qr/undef not supported/,

    '-not undef',
    { -not => undef },
    qr/undef not supported/,
);

test_queries(
    'SINGLE AND|OR|NOT',

    '-and1',
    { -and => [ k => 1 ] },
    { text => { k => 1 } },

    '-or1',
    { -or  => [ k => 1 ] },
    { text => { k => 1 } },

    '-not',
    { -not => [ k => 1 ] },
    { bool => { must_not => [ { text => { k => 1 } } ] } },
);

my %and_or = (
    and => {
        bool => { must => [ { text => { a => 1 } }, { text => { b => 2 } } ] }
    },
    or => {
        bool =>
            { should => [ { text => { a => 1 } }, { text => { b => 2 } } ] }
    },
    or_and => {
        bool => {
            must   => [ { text => { c => 3 } } ],
            should => [ { text => { a => 1 } }, { text => { b => 2 } } ]

        }
    },
    and_or => {
        bool => {
            should => [ {
                    bool => {
                        must => [
                            { text => { a => 1 } }, { text => { b => 2 } }
                        ]
                    }
                },
                { text => { c => 3 } }
            ]
        }
    },
    or_or => {
        bool => {
            should => [
                { text => { a => 1 } }, { text => { b => 2 } },
                { text => { c => 3 } }

            ]
        }
    },
);

test_queries(
    'BASIC AND|OR',

    '{and[]}',
    { -and => [ a => 1, b => 2 ] },
    $and_or{and},

    '[and[]]',
    [ -and => [ a => 1, b => 2 ] ],
    $and_or{and},

    '{or[]}',
    { -or => [ a => 1, b => 2 ] },
    $and_or{or},

    '[or[]]',
    [ -or => [ a => 1, b => 2 ] ],
    $and_or{or},

    '{and{}}',
    { -and => { a => 1, b => 2 } },
    $and_or{and},

    '[and{}]',
    [ -and => { a => 1, b => 2 } ],
    $and_or{and},

    '{or{}}',
    { -or => { a => 1, b => 2 } },
    $and_or{or},

    '[or{}]',
    [ -or => { a => 1, b => 2 } ],
    $and_or{or},
);

test_queries(
    'NESTED []{}',

    '{-or[[],kv]}',
    { -or => [ [ a => 1, b => 2 ], c => 3 ] },
    $and_or{or_or},

    '{-and[[],kv]}',
    { -and => [ [ a => 1, b => 2 ], c => 3 ] },
    $and_or{or_and},

    '[-or[[],kv]]',
    [ -or => [ [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{or_or},

    '[-and[[],kv]]',
    [ -and => [ [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{or_and},

    '{-and[-or[],kv]}',
    { -and => [ -or => [ a => 1, b => 2 ], c => 3 ] },
    $and_or{or_and},

    '{-or[-and[],kv]}',
    { -or => [ -and => [ a => 1, b => 2 ], c => 3 ] },
    $and_or{and_or},

    '[-and[-or[],kv]]',
    [ -and => [ -or => [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{or_and},

    '[-or[-and[],kv]]',
    [ -or => [ -and => [ a => 1, b => 2 ], c => 3 ] ],
    $and_or{and_or},
);

test_queries(
    'MULTI OPS',

    'K[-and @V]',
    { k => [ -and => 1, 2, 3 ] },
    {   bool => {
            must => [
                { text => { k => 1 } },
                { text => { k => 2 } },
                { text => { k => 3 } }
            ]
        }
    },

    'K[-and @{kv}]',
    { k => [ -and => { '^' => 1 }, { '^' => 2 }, { '^' => 3 } ] },
    {   bool => {
            must => [
                { text_phrase_prefix => { k => 1 } },
                { text_phrase_prefix => { k => 2 } },
                { text_phrase_prefix => { k => 3 } }
            ]
        }
    },

    'K{=[-and,@v]}',
    { k => { '=' => [ '-and', 1, 2 ] } },
    {   bool => {
            should => [
                { text => { k => '-and' } },
                { text => { k => 1 } },
                { text => { k => 2 } }
            ]
        }
    },

    'K{-or{}}',
    { k => { -or => { '!=' => 1, '=' => 2 } } },
    qr/Unknown query operator/,

    'K=>[-and[],{}]',
    { k => [ -and => [ 1, 2 ], { '^' => 3 } ] },
    {   bool => {
            must => [ { text_phrase_prefix => { k => 3 } } ],
            should => [ { text => { k => 1 } }, { text => { k => 2 } } ]
        }
    },

    '-and[],kv,-or{}',
    { -and => [ a => 1, b => 2 ], x => 9, -or => { c => 3, d => 4 } },
    {   bool => {
            must => [
                { text => { a => 1 } },
                { text => { b => 2 } },
                { text => { x => 9 } }
            ],
            should => [ { text => { c => 3 } }, { text => { d => 4 } } ],
        }
    },

    '{-and[@kv,k[]],kv,-or{@kv,k[]}}',
    {   -and => [ a => 1, b => 2, k => [ 11, 12 ] ],
        x    => 9,
        -or => { c => 3, d => 4, l => { '=' => [ 21, 22 ] } }
    },
    {   bool => {
            must => [
                { text => { a => 1 } },
                { text => { b => 2 } },
                {   bool => {
                        should => [
                            { text => { c => 3 } },
                            { text => { d => 4 } },
                            { text => { l => 21 } },
                            { text => { l => 22 } },
                        ]
                    }
                },
                { text => { x => 9 } }
            ],
            should => [ { text => { k => 11 } }, { text => { k => 12 } }, ]
        }
    },

    '{-or[@kv,k[]],kv,-and{@kv,k[]}}',
    {   -or => [ a => 1, b => 2, k => [ 11, 12 ] ],
        x   => 9,
        -and => { c => 3, d => 4, l => { '=' => [ 21, 22 ] } }
    },
    {   bool => {
            must => [
                { text => { c => 3 } },
                { text => { d => 4 } },
                {   bool => {
                        should => [
                            { text => { a => 1 } },
                            { text => { b => 2 } },
                            { text => { k => 11 } },
                            { text => { k => 12 } },
                        ]
                    }
                },
                { text => { x => 9 } },
            ],
            should => [ { text => { l => 21 } }, { text => { l => 22 } }, ]
        }
    },

    '[-or[],-or[],kv,-and[],[@kv,-and[],{}',
    [   -or  => [ a => 1, b => 2 ],
        -or  => { c => 3, d => 4 },
        e    => 5,
        -and => [ f => 6, g => 7 ],
        [ h => 8,  i => 9, -and => [ k => 10, l => 11 ] ],
        { m => 12, n => 13 }
    ],
    {   bool => {
            should => [
                { text => { a => 1 } },
                { text => { b => 2 } },
                { text => { c => 3 } },
                { text => { d => 4 } },
                { text => { e => 5 } },
                {   bool => {
                        must => [
                            { text => { f => 6 } }, { text => { g => 7 } }
                        ]
                    }
                },
                { text => { h => 8 } },
                { text => { i => 9 } },
                {   bool => {
                        must => [
                            { text => { k => 10 } },
                            { text => { l => 11 } }
                        ]
                    }
                },
                {   bool => {
                        must => [
                            { text => { m => 12 } },
                            { text => { n => 13 } }
                        ]
                    }
                },

            ]
        }
    },

    'K[-and mixed []{} ]',
    {   foo => [
            '-and',
            [ { '^' => 'foo' }, { 'gt' => 'moo' } ],
            { '^' => 'bar', 'lt' => 'baz' },
            [ { '^' => 'alpha' }, { '^' => 'beta' } ],
            [ { '!=' => 'toto', '=' => 'koko' } ],
        ]
    },
    {   bool => {
            must => [
                { text_phrase_prefix => { foo => 'bar' } },
                { range              => { foo => { lt => 'baz' } } },
                {   bool => {
                        should => [
                            { text_phrase_prefix => { foo => 'alpha' } },
                            { text_phrase_prefix => { foo => 'beta' } }
                        ]
                    }
                },
                { text => { foo => 'koko' } }
            ],
            should => [
                { text_phrase_prefix => { foo => 'foo' } },
                { range              => { foo => { gt => 'moo' } } }
            ],
            must_not => [ { text => { foo => 'toto' } } ]
        }
    },

    '[-and[],-or[],k[-and{}{}]',
    [   -and => [ a => 1, b => 2 ],
        -or  => [ c => 3, d => 4 ],
        e => [ -and => { '^' => 'foo' }, { '^' => 'bar' } ],
    ],
    {   bool => {
            should => [ {
                    bool => {
                        must => [
                            { text => { a => 1 } }, { text => { b => 2 } }
                        ]
                    }
                },
                { text => { c => 3 } },
                { text => { d => 4 } },
                {   bool => {
                        must => [
                            { text_phrase_prefix => { e => 'foo' } },
                            { text_phrase_prefix => { e => 'bar' } }
                        ]
                    }
                }
            ]
        }
    },

    '[-and[{},{}],-or{}]',
    [ -and => [ { foo => 1 }, { bar => 2 } ], -or => { baz => 3 } ],
    {   bool => {
            should => [ {
                    bool => {
                        must => [
                            { text => { foo => 1 } },
                            { text => { bar => 2 } }
                        ]
                    }
                },
                { text => { baz => 3 } }
            ]
        }
    },

    # -and has only 1 following element, thus all still ORed
    'k[-and[]]',
    { k => [ -and => [ { '=' => 1 }, { '=' => 2 }, { '=' => 3 } ] ] },
    {   bool => {
            should => [
                { text => { k => 1 } },
                { text => { k => 2 } },
                { text => { k => 3 } }
            ]
        }
    }
);

test_queries(
    'NOT',

    'not [k]',
    { -not => ['k'] },
    qr/UNDEF not a supported/,

    'not{k=>v}',
    { -not => { k => 'v' } },
    { bool => { must_not => [ { text => { k => 'v' } } ] } },

    'not{k{=v}}',
    { -not => { k => { '=' => 'v' } } },
    { bool => { must_not => [ { text => { k => 'v' } } ] } },

    'not[k=>v]',
    { -not => [ k => 'v' ] },
    { bool => { must_not => [ { text => { k => 'v' } } ] } },

    'not[k{=v}]',
    { -not => [ k => { '=' => 'v' } ] },
    { bool => { must_not => [ { text => { k => 'v' } } ] } },

    'not{k1=>v,k2=>v}',
    { -not => { k1 => 'v', k2 => 'v' } },
    {   bool => {
            must_not => [ {
                    bool => {
                        must => [
                            { text => { k1 => 'v' } },
                            { text => { k2 => 'v' } }
                        ]
                    }
                }
            ]
        }
    },

    'not{k{=v,^v}}',
    { -not => { k => { '=' => 'v', '^' => 'v' } } },
    {   bool => {
            must_not => [ {
                    bool => {
                        must => [
                            { text               => { k => 'v' } },
                            { text_phrase_prefix => { k => 'v' } }
                        ]
                    }
                }
            ]
        }
    },

    'not[k1=>v,k2=>v]',
    { -not => [ k1 => 'v', k2 => 'v' ] },
    {   bool => {
            must_not =>
                [ { text => { k1 => 'v' } }, { text => { k2 => 'v' } } ]
        }
    },

    'not[k{=v,^v}]',
    { -not => [ k => { '=' => 'v', '^' => 'v' } ] },
    {   bool => {
            must_not => [ {
                    bool => {
                        must => [
                            { text               => { k => 'v' } },
                            { text_phrase_prefix => { k => 'v' } }
                        ]
                    }
                }
            ]
        }
    },

    'not not',
    { -not => { -not => { k => 'v' } } },
    { text => { k    => 'v' } },

    'not !=',
    { -not => { k => { '!=' => 'v' } } },
    { text => { k => 'v' } },

    'not [{}{}]',
    { -not => { foo => [ 1, 2 ], bar => [ 1, 2 ], baz => { '!=' => 3 } } },
    {   bool => {
            must_not => [ {
                    bool => {
                        must => [ {
                                bool => {
                                    should => [
                                        { text => { foo => 1 } },
                                        { text => { foo => 2 } }
                                    ]
                                }
                            }
                        ],
                        must_not => [ { text => { baz => 3 } } ],
                        should   => [
                            { text => { bar => 1 } },
                            { text => { bar => 2 } }
                        ]
                    }
                }
            ]
        }
    }
);

done_testing;

#===================================
sub test_queries {
#===================================
    note "\n" . shift();
    while (@_) {
        my $name = shift;
        my $in   = shift;
        my $out  = shift;

        if ( ref $out eq 'Regexp' ) {
            throws_ok { $a->query($in) } $out, $name;
        }
        else {
            eval {
                eq_or_diff scalar $a->query($in), { query => $out }, $name;
                1;
            }
                or die "*** FAILED TEST $name:***\n$@";
        }
    }
}
