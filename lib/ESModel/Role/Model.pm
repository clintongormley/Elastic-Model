package ESModel::Role::Model;

use Moose::Role;
use Carp;
use ESModel::Types qw(ES);
use ElasticSearch();
use Moose::Util qw(does_role);
use MooseX::Types::Moose qw(:all);
use ESModel::View();
use ESModel::Store();
use Scalar::Util qw(blessed);

use namespace::autoclean;

#===================================
has 'type_map' => (
#===================================
    isa     => 'Str',
    is      => 'ro',
    lazy    => 1,
    default => 'ESModel::TypeMap::Default'
);

#===================================
has 'deflators' => (
#===================================
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {} }
);

#===================================
has 'inflators' => (
#===================================
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { {} }
);

#===================================
has 'store' => (
#===================================
    does    => 'ESModel::Role::Store',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_store'
);

#===================================
has 'es' => (
#===================================
    isa     => ES,
    is      => 'ro',
    lazy    => 1,
    builder => '_build_es'
);

#===================================
has '_index_cache' => (
#===================================
    isa     => HashRef,
    is      => 'bare',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        _get_index   => 'get',
        _cache_index => 'set',
    },
);

#===================================
has '_live_indices' => (
#===================================
    isa     => HashRef,
    is      => 'bare',
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
sub BUILD {
#===================================
    my $self = shift;
    Class::MOP::load_class( $self->type_map );
}

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

    my $uid = ESModel::UID->new(%params);

    my $class = $self->index( $uid->index )->class_for_type( $uid->type );
    return $class->new(
        %params,
        model => $self,
        uid   => $uid,
    );
}

#===================================
sub get_doc {
#===================================
    my $self = shift;
    my $params
        = !ref $_[0] ? {@_}
        : blessed $_[0] ? { uid => shift() }
        :                 shift;

    my $uid = $params->{uid} ||= ESModel::UID->new(@_);
    my $source = $params->{_source};
    unless ( $source || $uid->from_store ) {
        $source = $self->get_raw_doc($uid);
    }

    my $class = $self->index( $uid->index )->class_for_type( $uid->type );
    $class->_new_stub(
        model   => $self,
        uid     => $uid,
        _source => $source
    );
}

#===================================
sub get_raw_doc {
#===================================
    my $self = shift;
    my $uid  = shift;

    my $result = $self->store->get_doc($uid);
    $uid->update_from_store($result);
    return $result->{_source};
}

#===================================
sub save_doc {
#===================================
    my $self   = shift;
    my $doc    = shift;
    my %args   = ref $_[0] ? %{ shift() } : @_;
    my $uid    = $doc->uid;
    my $action = $uid->from_store ? 'index_doc' : 'create_doc';
    my $data   = $self->deflate_object($doc);
    my $result = $self->store->$action( $uid, $data, \%args );
    $uid->update_from_store($result);
    return $doc;
}

#===================================
sub delete_doc {
#===================================
    my $self   = shift;
    my $doc    = shift;
    my %args   = ref $_[0] ? %{ shift() } : @_;
    my $uid    = $doc->uid;
    my $result = $self->store->delete_doc( $doc->uid, \%args );
    $uid->update_from_store($result);
    return $doc;
}

#===================================
sub search { shift->store->search(@_) }
#===================================

#===================================
sub deflate_object {
#===================================
    my $self   = shift;
    my $object = shift or die "No object passed to deflate()";
    my $class  = blessed $object
        or die "deflate() can only deflate objects";
    $self->deflator_for_class($class)->( $object, $self );
}

#===================================
sub deflator_for_class {
#===================================
    my $self  = shift;
    my $class = shift;
    return $self->deflators->{$class} ||= do {
        die "Class $class is not an ESModel class."
            unless does_role( $class, 'ESModel::Role::Doc' );
        $self->type_map->class_deflator($class);

    };
}

#===================================
sub inflate_object {
#===================================
    my $self   = shift;
    my $object = shift or die "No object passed to inflate()";
    my $hash   = shift or die "No hash pashed to inflate()";
    $self->inflator_for_class( blessed $object)->( $object, $hash, $self );
}

#===================================
sub inflator_for_class {
#===================================
    my $self  = shift;
    my $class = shift;
    return $self->inflators->{$class} ||= do {
        die "Class $class is not an ESModel class."
            unless does_role( $class, 'ESModel::Role::Doc' );
        $self->type_map->class_inflator($class);

    };
}

#===================================
sub map_class {
#===================================
    my $self  = shift;
    my $class = shift;
    die "Class $class is not an ESModel class."
        unless does_role( $class, 'ESModel::Role::Doc' );

    my $meta    = $class->meta;
    my %mapping = (
        $self->type_map->class_mapping($class),
        %{ $meta->root_class_mapping }
    );
    return \%mapping;
}

1;
