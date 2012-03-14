package ESModel::Role::Model;

use Moose::Role;
use Carp;
use ESModel::Types qw(ES);
use ElasticSearch();
use Class::Load qw(load_class);
use Moose::Util qw(does_role);
use MooseX::Types::Moose qw(:all);
use ESModel::UID();
use Scalar::Util qw(blessed);

use namespace::autoclean;

our %Default_Class = (
    type_map               => 'ESModel::TypeMap::Default',
    index_class            => 'ESModel::Index',
    store_class            => 'ESModel::Store',
    view_class             => 'ESModel::View',
    scope_class            => 'ESModel::Scope',
    results_class          => 'ESModel::Results',
    scrolled_results_class => 'ESModel::Results::Scrolled',
    result_class           => 'ESModel::Result',
);

#===================================
has $_ => (
#===================================
    isa     => Str,
    is      => 'ro',
    default => $Default_Class{$_},
    writer  => "_set_$_"
) for keys %Default_Class;

#===================================
has [ 'deflators', 'inflators' ] => (
#===================================
    isa     => HashRef,
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
has 'class_wrappers' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    lazy    => 1,
    builder => '_build_class_wrappers',
    handles => { class_wrapper => 'get' }
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
has 'current_scope' => (
#===================================
    is       => 'rw',
    isa      => 'ESModel::Scope',
    lazy     => 1,
    weak_ref => 1,
    builder  => '_die_no_scope'
);

#===================================
sub BUILD {
#===================================
    my $self = shift;
    for ( keys %Default_Class ) {
        my $class = $self->wrap_class( $self->$_ );
        my $set   = "_set_$_";
        $self->$set($class);
    }
    $self->class_wrappers;
}

#===================================
sub _build_store { $_[0]->store_class->new( es => $_[0]->es ) }
sub _build_es { ElasticSearch->new }
sub _die_no_scope { croak "There is no current_scope" }
#===================================

#===================================
sub _build_class_wrappers {
#===================================
    my $self    = shift;
    my $indices = $self->meta->indices;
    my %classes;
    for my $types ( values %$indices ) {
        $classes{$_} = $self->wrap_doc_class($_) for values %$types;
    }
    \%classes;
}

#===================================
sub wrap_doc_class {
#===================================
    my $self  = shift;
    my $class = shift;

    load_class($class);

    $class->meta->make_mutable;

    my $orig_meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $class,
        class_metaroles => {
            instance  => ['ESModel::Meta::Instance'],
            attribute => ['ESModel::Trait::Field'],
        }
    );

    my $meta = Moose::Meta::Class->create_anon_class(
        superclasses => [$class],
        roles        => ['ESModel::Role::Doc'],
        weaken       => 0,
    );

    $meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $meta,
        class_metaroles => {
            class => [ 'ESModel::Meta::Class', 'ESModel::Meta::Class::Doc' ],
            instance => ['ESModel::Meta::Instance'],
        }
    );

    $meta->_set_original_class($class);
    $meta->_set_model($self);
    $meta->make_immutable;
    $orig_meta->make_immutable;
    return $meta->name;
}

#===================================
sub wrap_class {
#===================================
    my $self  = shift;
    my $class = shift;

    load_class($class);

    my $meta = Moose::Meta::Class->create_anon_class(
        superclasses => [$class],
        weaken       => 0,
    );

    $meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $meta,
        class_metaroles => { class => ['ESModel::Meta::Class'], }
    );

    $meta->_set_original_class($class);
    $meta->_set_model($self);
    $meta->add_method( model => sub { shift->meta->model } );
    $meta->make_immutable;
    return $meta->name;
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
        my $types = $self->meta->index($base_name);
        unless ($types) {
            my $live_index = $self->_live_index($base_name)
                || $self->_clear_live_indices
                && $self->_live_index($base_name)
                || croak "Unknown index name '$base_name'";
            $types = $self->meta->index($live_index);
        }
        my %classes
            = map { $_ => $self->class_wrapper( $types->{$_} ) } keys %$types;
        $index = $self->index_class->new(
            name  => $dest_name,
            types => \%classes
        );
        $self->_cache_index( $dest_name => $index );
    }

    return $index;
}

#===================================
sub view { shift->view_class->new(@_) }
#===================================

#===================================
sub new_scope {
#===================================
    my $self = shift;
    $self->current_scope( $self->scope_class->new );
}

#===================================
sub new_doc {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;

    my $uid = ESModel::UID->new(%params);

    my $class = $self->index( $uid->index )->class_for_type( $uid->type );
    return $class->new( %params, uid => $uid, );
}

#===================================
sub get_doc {
#===================================
    my $self = shift;
    my $params
        = !ref $_[0] ? {@_}
        : blessed $_[0] ? { uid => shift() }
        :                 shift;

    my $scope  = $self->current_scope;
    my $uid    = $params->{uid} ||= ESModel::UID->new($params);
    my $object = $scope->get_object($uid) unless $params->{_source};
    unless ($object) {
        my $source = $params->{_source};
        $source = $self->get_raw_doc($uid) unless $source || $uid->from_store;

        my $class = $self->index( $uid->index )->class_for_type( $uid->type );
        $object = $class->meta->new_stub(
            uid     => $uid,
            _source => $source
        );
        $object = $scope->store_object($object);
    }
    $object;
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
    return $self->scope->store_object($doc);
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

    my $meta         = $class->meta->original_class->meta;
    my %root_mapping = %{ $meta->root_class_mapping }
        if $meta->can('root_class_mapping');

    my %mapping = ( $self->type_map->class_mapping($class), %root_mapping );
    return \%mapping;
}

1;
