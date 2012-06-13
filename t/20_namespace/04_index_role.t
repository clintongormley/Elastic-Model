#!/usr/bin/perl

use strict;
use warnings;
use Test::More 0.96;
use Test::Moose;
use Test::Deep;

use lib 't/lib';

do 'es.pl';
our $es = get_es();

$es->delete_index( index => $_, ignore_missing => 1 ) for qw(myapp3 myapp4);

wait_for_es();

use_ok 'MyApp' || print 'Bail out';

my $model = new_ok( 'MyApp', [ es => $es ], 'Model' );
ok my $ns = $model->namespace('myapp'), 'Got ns';

## TEST INDEX ##
isa_ok my $index = $ns->index('myapp3'), 'Elastic::Model::Index',
    'Index myapp3';
ok $index->create, 'Create index myapp3';

test_domain( $index, 'Index', 'myapp3' );


## TEST SINGLE INDEX ALIAS ##
ok $index->create, 'Recreate index myapp3';

isa_ok my $alias = $ns->alias, 'Elastic::Model::Alias', 'Alias myapp';
ok $alias->to('myapp3'), 'Aliased to myapp3';

test_domain( $alias, 'Alias', 'myapp' );

## TEST MULTI INDEX ALIAS ##
ok $index->create, 'Recreate index myapp3';
ok $ns->index('myapp4')->create, 'Create index myapp4';
ok $alias->to( 'myapp3', 'myapp4' ), 'Alias myapp to myapp3 and myapp4';

test_domain( $alias, 'Multi-alias', 'myapp' );


done_testing;

sub test_domain {
    my ( $index, $desc, $name ) = @_;

    note "";
    note "Testing $desc";
    note "";

    ## Exists and is ##

    ok $index->exists, "$desc exists";
    if ( $desc =~ /Index/ ) {
        ok $index->is_index, "$desc is index";
        ok !$index->is_alias, "$desc is not alias";

    }
    else {
        ok !$index->is_index, "$desc is not index";
        ok $index->is_alias, "$desc is alias";
    }

    ## Mappings ##
    isa_ok
        my $mapping = $es->mapping( index => $name )->{'myapp3'},
        "HASH",
        "$desc mapping from ES";

    cmp_deeply
        [ keys %$mapping ],
        [ "user", "post" ],
        "$desc ES mapping has both types";

    ok $index->delete_mapping("post"), "Delete $desc mapping";
    wait_for_es(1);

    ok !$es->mapping( index => $name )->{$name}{post},
        "$desc mapping deleted";
    ok $index->update_mapping("post"), "Update $desc mapping";
    ok $es->mapping( index => $name, type => "post" )->{post},
        "Mapping $desc recreated";

    ## Refresh ##
    ok $index->refresh, "$desc refreshed";

    ## Update settings ##
    sub get_interval {
        my $name = shift;
        $es->index_settings( index => $name )
            ->{myapp3}{settings}{"index.refresh_interval"};
    }

    ok !get_interval($name), "$desc - no refresh interval set";
    ok $index->update_settings( refresh_interval => -1 ),
        "$desc - disable refresh";
    is get_interval($name), -1, "$desc - refresh disabled";
    ok $index->update_settings( refresh_interval => "1s" ),
        "Enable $desc refresh";
    is get_interval(), "1s", "Refresh $desc enabled";

SKIP: {
        skip "Cannot open/close multi-aliases", 11
            if $desc =~ /Multi/;

        ## Open / close ##
        sub the_index {
            my $name = shift;
            $es->index_status( index => $name )->{_shards}{total} == 10
                ? "open"
                : "closed";
        }

        is the_index($name), "open", "$desc open";
        ok $index->close, "Close $desc";
        is the_index($name), "closed", "$desc closed";
        ok $index->open, "Open $desc";
        is the_index($name), "open", "$desc re-opened";

        ## Update analyzers ##
        sub get_tokenizer {
            my $name = shift;
            $es->index_settings( index => $name )
                ->{myapp3}{settings}
                {"index.analysis.analyzer.edge_ngrams.tokenizer"};
        }

        is get_tokenizer($name), "standard", "$desc tokenizer is standard";
        ok $index->close, "Close $desc";

        ok $index->update_settings(
            "analysis.analyzer.edge_ngrams.tokenizer" => "keyword" ),
            "Set $desc tokenizer to keyword";
        is get_tokenizer($name), "keyword", "$desc tokenizer is keyword";

        ok $index->update_analyzers(), "Update $desc analyzers";
        is get_tokenizer($name), "standard",
            "$desc tokenizer reset to standard";
    }

    ## Delete index ##
    ok $index->delete, "Delete $desc ";
    ok !$index->exists, "$desc deleted";

}

__END__
