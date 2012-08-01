#!/usr/bin/perl

use strict;
use warnings;
use Test::More 0.96;
use Test::Exception;
use Test::Deep;
use Scalar::Util qw(refaddr);

use lib 't/lib';

our $es;
do 'es.pl';

use_ok 'MyAppUniq' || print 'Bail out';

my $model = new_ok( 'MyAppUniq', [ es => $es ], 'Model' );
ok my $ns = $model->namespace('myapp'), 'Got ns';
ok $ns->index->create, 'Create index myapp';
ok my $domain = $model->domain('myapp'), 'Got domain';

is $model->meta->unique_index,
    'myapp1',
    'Unique index set';

isa_ok
    my $uniq = $model->es_unique,
    'ElasticSearchX::UniqueKey',
    'model->es_unique';

ok $es->index_exists( index => 'myapp1' ), 'Unique index created';

# Create doc
isa_ok my $user = $domain->new_doc(
    user => {
        name         => 'John',
        account_type => 'facebook',
        email        => 'john@foo.com',
    }
    ),
    'MyApp::UniqUser', 'User';

ok $user->save, 'Save user';

cmp_deeply + {
    $uniq->multi_exists(
        email        => 'john@foo.com',
        account_type => 'facebook',
        compound     => 'facebook:john@foo.com'
    )
    },
    {}, 'Unique keys created';

# Update non-unique keys
is $user->name('James'), 'James', 'Change name field';
ok $user->save, 'Non-unique changed user saved';

# Update unique keys
is $user->email('james@foo.com'), 'james@foo.com', 'Change email';
ok $user->save, 'Unique changed user saved';

cmp_deeply + {
    $uniq->multi_exists(
        email        => 'john@foo.com',
        account_type => 'facebook',
        compound     => 'facebook:john@foo.com'
    )
    },
    {
    email    => 'john@foo.com',
    compound => 'facebook:john@foo.com'
    },
    'Old unique keys removed';

cmp_deeply + {
    $uniq->multi_exists(
        email        => 'james@foo.com',
        account_type => 'facebook',
        compound     => 'facebook:james@foo.com'
    )
    },
    {}, 'New unique keys created';

# Create new doc with clashing keys

isa_ok $user = $domain->new_doc(
    user => {
        id           => 1,
        name         => 'Mary',
        account_type => 'facebook',
        email        => 'mary@foo.com',
    }
    ),
    'MyApp::UniqUser', 'User';

throws_ok sub { $user->save },
    qr{Unique keys already exist: account_type/facebook},
    'Save conflicted user';

# On Unique
my $on_unique;
ok $user->save(
    on_unique => sub {
        my ( $u, $f ) = @_;
        $on_unique++;
        is refaddr $u, refaddr $user, 'User passed to on_unique';
        cmp_deeply $f, { account_type => 'facebook' },
            'Failed keys passed to on_unique';
    }
    ),
    'Save with on_unique ';

ok $on_unique, 'on_unique called';

cmp_deeply + {
    $uniq->multi_exists(
        email        => 'mary@foo.com',
        compound     => 'facebook:mary@foo.com',
        account_type => 'facebook',
    )
    },
    {
    email    => 'mary@foo.com',
    compound => 'facebook:mary@foo.com',
    },
    'New unique keys not created';

# Save second user
is $user->account_type('fb'), 'fb', 'Updated account_type';
ok $user->save, 'Second user saved';

cmp_deeply + {
    $uniq->multi_exists(
        email        => 'mary@foo.com',
        account_type => 'fb',
        compound     => 'fb:mary@foo.com'
    )
    },
    {}, 'New unique keys created';

is $user->account_type('facebook'), 'facebook',
    'Changed account_type to clashing';
is $user->email('alice@foo.com'), 'alice@foo.com',
    'Changed email to new unique';

# Update clashing
throws_ok sub { $user->save },
    qr{Unique keys already exist: account_type/facebook},
    'Update to conflicted';

cmp_deeply + {
    $uniq->multi_exists(
        email        => 'mary@foo.com',
        account_type => 'fb',
        compound     => 'fb:mary@foo.com'
    )
    },
    {}, 'Old keys still exist';

cmp_deeply + {
    $uniq->multi_exists(
        email    => 'alice@foo.com',
        compound => 'facebook:mary@foo.com'
    )
    },
    {
    email    => 'alice@foo.com',
    compound => 'facebook:mary@foo.com'
    },
    'New keys not created';

# Rollback save
isa_ok $user = $domain->new_doc(
    user => {
        id           => 1,
        name         => 'Alex',
        account_type => 'twitter',
        email        => 'alex@foo.com',
    }
    ),
    'MyApp::UniqUser', 'User';

throws_ok sub { $user->overwrite },
    qr/Cannot overwrite a new doc/,
    "Can't overwrite unsaved docs with uniques";

throws_ok sub { $user->save },
    qr/ElasticSearch::Error::Conflict/,
    'Conflict error';

cmp_deeply + {
    $uniq->multi_exists(
        account_type => 'twitter',
        email        => 'alex@foo.com',
        compound     => 'twitter:alex@foo.com'
    )
    },
    {
    account_type => 'twitter',
    email        => 'alex@foo.com',
    compound     => 'twitter:alex@foo.com'
    },
    'New keys rolled back';

# Optional keys
isa_ok $user= $domain->get( user => 1 ), 'MyApp::UniqUser', 'Retrieved user';
is $user->optional('foo'), 'foo', 'Updated optional';
ok $user->save, 'Saved with optional';
cmp_deeply + {
    $uniq->multi_exists(
        email        => 'mary@foo.com',
        account_type => 'fb',
        compound     => 'fb:mary@foo.com',
        optional     => 'foo'
    )
    },
    {}, 'Optional key created';
ok $user->clear_optional, 'Optional cleared';
ok $user->save,           'Saved without optional';
cmp_deeply + {
    $uniq->multi_exists(
        email        => 'mary@foo.com',
        account_type => 'fb',
        compound     => 'fb:mary@foo.com',
        optional     => 'foo'
    )
    },
    {
    optional => 'foo'

    },
    'Optional key deleted';

# Delete keys
ok $user->delete, 'User deleted';

cmp_deeply + {
    $uniq->multi_exists(
        email        => 'mary@foo.com',
        account_type => 'fb',
        compound     => 'fb:mary@foo.com'
    )
    },
    {
    email        => 'mary@foo.com',
    account_type => 'fb',
    compound     => 'fb:mary@foo.com'

    },
    'Old keys deleted';

# Delete non-existent
ok !$domain->try_delete( user => 1 ), 'Non-existent user try_deleted';

## DONE ##

done_testing;

__END__
