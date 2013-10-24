#!/usr/bin/perl

use strict;
use warnings;
use Test::More 0.96;
use Test::Exception;
use Test::Deep;
use Elasticsearch;

use lib 't/lib';

our $es;
do 'es.pl';

my $orig = Elasticsearch::Client::Compat->can('reindex');
my $callback = sub {1};

{
    no warnings( 'redefine', 'once' );
    *Elasticsearch::Client::Compat::reindex = sub {
        my $self = shift;
        $callback->(@_)
            and $self->$orig(@_);
    };
}

use_ok 'MyApp' || print 'Bail out';

my $model = new_ok( 'MyApp', [ es => $es ], 'Model' );
ok my $ns = $model->namespace('myapp'), 'Got ns';

create_users($model);
isa_ok my $new = $ns->index('myapp4'), 'Elastic::Model::Index', 'New index';

# No opts
throws_ok sub { $new->reindex }, qr/No \(domain\)/, 'Missing domain';

# Domain reindex
ok $new->reindex('myapp'), 'Reindex domain myapp to myapp4';
compare_results(
    'Domain myapp reindexed to myapp4',
    { index => 'myapp' },
    { index => 'myapp4' }
);

# Params
$callback = sub {
    my %args = @_;
    is $args{quiet}                  => 1,    ' - quiet set';
    is $args{source}{search}{scroll} => '1m', ' - scan set';
    is $args{source}{search}{size}   => 10,   ' - size set';
    is $args{bulk_size}, 50, ' - bulk size set';
    return 0;
};

ok $new->reindex(
    'myapp',
    quiet     => 1,
    scan      => '1m',
    size      => 10,
    bulk_size => 50,
    ),
    'Args check';

done_testing;

#===================================
sub compare_results {
#===================================
    my ( $desc, $q1, $q2 ) = @_;

    $model->es->refresh_index();

    my @r1 = map { delete $_->{_index}; $_ } @{
        $model->es->search(
            size   => 300,
            query  => { match_all => {} },
            'sort' => ['timestamp'],
            %$q1
        )->{hits}{hits}
    };

    my @r2 = map { delete $_->{_index}; $_ } @{
        $model->es->search(
            size   => 300,
            query  => { match_all => {} },
            'sort' => ['timestamp'],
            %$q2
        )->{hits}{hits}
    };

    cmp_deeply \@r1, \@r2, $desc;
}
