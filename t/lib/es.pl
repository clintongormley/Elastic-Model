#!/usr/bin/env perl

use strict;
use warnings;
use ElasticSearch::TestServer;
use Test::More;

our $es;

eval {
    if ( $ENV{ES} )
    {
        $es = ElasticSearch->new( servers => $ENV{ES} );
        $es->current_server_version;
    }
    elsif ( $ENV{ES_HOME} ) {
        $es = ElasticSearch::TestServer->new(
            instances => 1,
            home      => $ENV{ES_HOME},
            transport => 'http'
        );
    }
    1;
} or do { diag $_ for split /\n/, $@; undef $es };

if ($es) {
    $es->delete_index( index => $_, ignore_missing => 1 )
        for qw(myapp myapp1 myapp2 myapp3 myapp4 myapp5);
    wait_for_es();
    return $es;
}

plan skip_all => 'No ElasticSearch test server available';
exit;

#===================================
sub wait_for_es {
#===================================
    $es->cluster_health( wait_for_status => 'yellow' );
    $es->refresh_index;
    sleep $_[0] if $_[0];
}
1;
