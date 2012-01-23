package ESModel::Role::Model;

use Moose::Role;
use Carp;
use ESModel::Types qw(ES);
use ElasticSearch();
use ESModel::DocSet();
use namespace::autoclean;

has 'es' => (
    isa        => ES,
    is         => 'ro',
    coerce     => 1,
    lazy_build => 1
);

has '_index_cache' => (
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        _get_index   => 'get',
        _cache_index => 'set',
    },
);

has '_live_indices' => (
    isa     => 'HashRef',
    is      => 'ro',
    traits  => ['Hash'],
    builder => '_update_live_indices',
    clearer => '_clear_live_indices',
    lazy    => 1,
    handles => { _live_index => 'get', },

);

#===================================
sub _build_es { ElasticSearch->new }
#===================================

#===================================
sub _update_live_indices {
#===================================
    my $self    = shift;
    my $meta    = $self->meta;
    my $indices = $self->es->get_aliases( index => [ $meta->all_indices ] )
        ->{indices};

    my %live;
    while ( my ( $name, $aliases ) = each %$indices ) {
        ( $live{$name} ) = grep { $self->index($_) }
            grep { $meta->has_index($_) } @$aliases;
    }
    \%live;
}

#===================================
sub index {
#===================================
    my $self = shift;
    my $name = shift or croak "No index name passed to index()";

    my $index = $self->_get_index($name);
    unless ($index) {
        my $opts = $self->meta->index($name);
        unless ($opts) {
            my $live_index
                = $self->_live_index($name)
                || $self->_clear_live_indices && $self->_live_index($name)
                || croak "Unknown index name '$name'";
            $opts = $self->meta->index($live_index);
        }
        $index = ESModel::Index->new(
            name  => $name,
            model => $self,
            %$opts
        );
        $self->_cache_index( $name => $index );
    }

    return $index;
}

#===================================
sub docset {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    ESModel::DocSet->new( %params, model => $self );
}

1;
