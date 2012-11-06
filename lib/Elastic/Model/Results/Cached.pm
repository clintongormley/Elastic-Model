package Elastic::Model::Results::Cached;

use Carp;
use Moose;
with 'Elastic::Model::Role::Results';
use MooseX::Types::Moose qw(Str Num Object HashRef);

use namespace::autoclean;

#===================================
has 'took' => (
#===================================
    isa    => Num,
    is     => 'ro',
    writer => '_set_took',
);

#===================================
has 'cache' => (
#===================================
    is       => 'ro',
    isa      => Object,
    required => 1,
);

#===================================
has 'cache_opts' => (
#===================================
    is  => 'ro',
    isa => HashRef,
);

#===================================
has 'cache_key' => (
#===================================
    is      => 'ro',
    isa     => Str,
    builder => '_build_cache_key',
    lazy    => 1,

);

no Moose;

our $json;
#===================================
sub _build_cache_key {
#===================================
    my $self = shift;
    require JSON;
    $json ||= JSON->new->canonical->utf8;
    return $json->encode( $self->search );
}

#===================================
sub BUILD {
#===================================
    my $self = shift;

    my $cache      = $self->cache;
    my $cache_opts = $self->cache_opts || {};
    my $cache_key  = $self->cache_key;

    my $cached;
    my $result = $cache->get( $cache_key, %$cache_opts )
        unless delete $cache_opts->{force_set};

    if ( defined $result ) {
        $cached++;
    }
    else {
        $result = $self->model->search( $self->search );
    }

    my $hits = $result->{hits};
    $self->_set_total( $hits->{total} );
    $self->_set_elements( $hits->{hits} );
    $self->_set_max_score( $hits->{max_score} || 0 );

    $self->_set_took( $result->{took} || 0 );
    $self->_set_facets( $result->{facets} || {} );

    $cache->set( $cache_key, $result, $cache_opts )
        unless $cached;
}

1;

__END__

# ABSTRACT: A cacheable iterator over bounded/finite search results

=head1 SYNOPSIS

    $cache   = CHI->new(...);
    $view    = $model->view
                     ->cache( $cache )
                     ->cache_opts( expires_in => '30 sec' );

    $results = $view->cached_search;
    $results = $view->cached_search( expires_in => '2 sec', force_set => 1 );


=head1 DESCRIPTION

An L<Elastic::Model::Results::Cached> object is returned when you call
L<Elastic::Model::View/cached_search()>, and behaves exactly the same
as L<Elastic::Model::Results> except that it will try to retrieve the
results from the cache, before hitting Elasticsearch.

=head1 ADDITIONAL ATTRIBUTES

=head2 cache

The L<CHI>-compatible cache object from L<Elastic::Model::View/cache>.

=head2 cache_opts

The combination of the default L<Elastic::Model::View/cache_opts> plus
any additional options passed in to L<Elastic::Model::View/cached_search()>.
These options are passed to
L<CHI's get() or set()|'https://metacpan.org/module/CHI#Getting-and-setting>
methods.

=head2 cache_key

The cache_key is a canonical JSON string representation of the full
L<Elastic::Model::Role::Results/search> parameter.
