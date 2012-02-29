package ESModel::Role::Model;

use Moose::Role;
use Carp;
use ESModel::Types qw(ES);
use ElasticSearch();
use MooseX::Types::Moose qw(:all);
use ESModel::View();
use ESModel::Store();
use namespace::autoclean;

has 'store' => (
    does       => 'ESModel::Role::Store',
    is         => 'ro',
    lazy_build => '_build_store'
);

has 'es' => (
    isa        => ES,
    is         => 'ro',
    coerce     => 1,
    lazy_build => 1
);

has '_index_cache' => (
    isa     => HashRef,
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        _get_index   => 'get',
        _cache_index => 'set',
    },
);

has '_live_indices' => (
    isa     => HashRef,
    is      => 'ro',
    traits  => ['Hash'],
    builder => '_update_live_indices',
    clearer => '_clear_live_indices',
    lazy    => 1,
    handles => { _live_index => 'get', },

);

#===================================
sub _build_store { ESModel::Store->new( model => shift() ) }
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
    my $self      = shift;
    my $base_name = shift or croak "No index name passed to index()";
    my $dest_name = @_ ? shift : $base_name;
    my $index     = $self->_get_index($dest_name);
    unless ($index) {
        my $opts = $self->meta->index($base_name);
        unless ($opts) {
            my $live_index = $self->_live_index($base_name)
                || $self->_clear_live_indices
                && $self->_live_index($base_name)
                || croak "Unknown index name '$base_name'";
            $opts = $self->meta->index($live_index);
        }
        $index = ESModel::Index->new(
            name  => $dest_name,
            model => $self,
            %$opts
        );
        $self->_cache_index( $dest_name => $index );
    }

    return $index;
}

#===================================
sub view {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    ESModel::View->new( %params, model => $self );
}

#===================================
sub new_doc {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;

    my ( $index, $type ) = delete @params{ 'index', 'type' };
    croak "A new doc must have a single index and a single type"
        unless $index && !ref $index && $type && !ref $type;

    my $class = $self->index($index)->class_for_type($type);
    return $class->new(
        model => $self,
        index => $index,
        type  => $type,
        %params
    );
}

#===================================
sub get_doc {
#===================================
    my $self   = shift;
    my $uid    = blessed $_[0] ? shift : ESModel::Doc::UID->new(@_);
    my $result = $self->store->get_doc($uid) or return;
    $uid->update_from_datastore($result);
    $self->inflate_doc( $uid, $result->{_source} );
}

#===================================
sub inflate_doc {
#===================================
    my $self   = shift;
    my $uid    = shift;
    my $source = shift;

    my $index = $self->index( $uid->index );
    my $class = $index->class_for_type( $uid->type );

    return $class->new(
        model => $self,
        uid   => $uid,
        %{ $class->inflate($source) }
    );
}

#===================================
sub inflate_or_get_doc {
#===================================
    my $self   = shift;
    my $params = shift;
    my $uid    = ESModel::Doc::UID->new_from_datastore($params);
    if ( my $source = $params->{_source} ) {
        return $self->inflate_doc( $uid, $source );
    }
    $self->get_doc($uid);
}

# TODO: inflate_docs
#===================================
sub inflate_docs {
#===================================
    my ( $self, $result ) = @_;

    #    my $uid = ESModel::Doc::UID->new_from_datastore($result);
    #    my $source   = $result->{_source}
    #        or return $self->get_doc( $uid->values );
    #
    #    my $class
    #        = $self->index( $uid->index )->class_for_type( $uid->type );
    #
    #    return $class->new(
    #        model    => $self,
    #        uid => $uid,
    #        %{ $class->inflate($source) }
    #    );
}

#===================================
sub search { shift->store->search(@_) }
#===================================

1;
