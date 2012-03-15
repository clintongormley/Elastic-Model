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
    domain_class           => 'ESModel::Domain',
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
    handles => {
        class_for   => 'get',
        knows_class => 'exists'
    }
);

#===================================
has '_domain_cache' => (
#===================================
    isa     => HashRef,
    is      => 'bare',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        _get_domain   => 'get',
        _cache_domain => 'set',
    },
);

#===================================
has '_index_domains' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
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
    my $domains = $self->meta->domains;
    my %classes;
    for my $types ( values %$domains ) {
        $classes{$_} = $self->wrap_doc_class($_) for values %$types;
    }
    \%classes;
}

#===================================
sub domain_for_index {
#===================================
    my $self = shift;
    my $index = shift or croak "No (index) passed to domain_for_index";
    my $domain;
    $domain = $self->_index_domains->{$index} and return $domain;
    $domain = $self->meta->domain($index)     and return $index;

    my $aliases = $self->es->get_aliases( index => $index )->{$index}{aliases}
        or croak "Unknown index ($index)";

    my $domains = $self->meta->domains;
    $domain = '';

    for ( keys %$aliases ) {
        if ( $domains->{$_} ) {
            croak "Index ($index) currently points to more than one domain"
                if $domain;
            $domain = $_;
        }
    }
    croak "No domain found for index ($index)" unless $domain;
    $self->_index_domains->{$index} = $domain;
    return $domain;
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
sub domain {
#===================================
    my $self   = shift;
    my $name   = shift or croak "No domain name passed to domain()";
    my $domain = $self->_get_domain($name);

    unless ($domain) {

        my $types = $self->meta->domain($name)
            or croak "Unknown domain name ($name)";

        my %classes
            = map { $_ => $self->class_for( $types->{$_} ) } keys %$types;

        $domain = $self->domain_class->new(
            name  => $name,
            types => \%classes
        );

        $self->_cache_domain( $name => $domain );
    }

    return $domain;
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
sub get_doc {
#===================================
    my ( $self, $uid, $source ) = @_;
    croak "No UID passed to get_doc()" unless $uid;

    my $domain = $self->domain_for_index( $uid->index );
    my $scope  = $self->current_scope;

    my $object;
    $object = $scope->get_object( $domain, $uid ) unless $source;

    unless ($object) {
        $source ||= $self->get_raw_doc($uid) unless $uid->from_store;
        my $class = $self->domain($domain)->class_for_type( $uid->type );
        $object = $class->meta->new_stub(
            uid     => $uid,
            _source => $source
        );
        $object = $scope->store_object( $domain, $object );
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
    my $domain = $self->domain_for_index( $uid->index );
    my $action = $uid->from_store ? 'index_doc' : 'create_doc';
    my $data   = $self->deflate_object($doc);
    my $result = $self->store->$action( $uid, $data, \%args );
    $uid->update_from_store($result);
    return $self->current_scope->store_object( $domain, $doc );
}

#===================================
sub delete_doc {
#===================================
    my $self   = shift;
    my $doc    = shift;
    my %args   = ref $_[0] ? %{ shift() } : @_;
    my $uid    = $doc->uid;
    my $domain = $self->domain_for_index( $uid->index );
    my $result = $self->store->delete_doc( $doc->uid, \%args );
    $uid->update_from_store($result);
    return $self->current_scope->delete_object( $domain, $doc );
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
