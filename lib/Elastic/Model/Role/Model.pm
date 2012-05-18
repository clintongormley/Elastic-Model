package Elastic::Model::Role::Model;

use Moose::Role;
use Carp;
use Elastic::Model::Types qw(ES);
use ElasticSearch 0.52 ();
use Class::Load qw(load_class);
use Moose::Util qw(does_role);
use MooseX::Types::Moose qw(:all);
use Elastic::Model::UID();
use Elastic::Model::Namespace();
use Scalar::Util qw(blessed refaddr weaken);
use List::MoreUtils qw(uniq);

use namespace::autoclean;

our %Default_Class = (
    type_map               => 'Elastic::Model::TypeMap::Default',
    domain_class           => 'Elastic::Model::Domain',
    store_class            => 'Elastic::Model::Store',
    view_class             => 'Elastic::Model::View',
    scope_class            => 'Elastic::Model::Scope',
    results_class          => 'Elastic::Model::Results',
    scrolled_results_class => 'Elastic::Model::Results::Scrolled',
    result_class           => 'Elastic::Model::Result',
);

for ( keys %Default_Class ) {
#===================================
    has $_ => (
#===================================
        isa     => Str,
        is      => 'ro',
        default => $Default_Class{$_},
        writer  => "_set_$_"
    );
}

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
    does    => 'Elastic::Model::Role::Store',
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
has 'doc_class_wrappers' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    lazy    => 1,
    builder => '_build_doc_class_wrappers',
    handles => {
        class_for   => 'get',
        knows_class => 'exists'
    }
);

#===================================
has 'namespaces' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    builder => '_build_namespaces',
    handles => { get_namespace => 'get' }
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
has '_index_namespace' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    lazy    => 1,
    builder => '_build_index_namespace',
    handles => {
        _clear_index_namespace => 'clear',
        _get_index_namespace   => 'get',
    }
);

#===================================
has 'current_scope' => (
#===================================
    is        => 'rw',
    isa       => 'Elastic::Model::Scope',
    lazy      => 1,
    weak_ref  => 1,
    builder   => '_die_no_scope',
    clearer   => 'clear_current_scope',
    predicate => 'has_current_scope',
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
    $self->doc_class_wrappers;
}

#===================================
sub _build_store { $_[0]->store_class->new( es => $_[0]->es ) }
sub _build_es { ElasticSearch->new }
sub _die_no_scope { croak "There is no current_scope" }
#===================================

#===================================
sub _build_namespaces {
#===================================
    my $self = shift;
    my $conf = $self->meta->namespaces;
    my %namespaces;

    while ( my ( $name, $types ) = each %$conf ) {
        my %classes
            = map { $_ => $self->class_for( $types->{$_} ) } keys %$types;
        $namespaces{$name} = Elastic::Model::Namespace->new(
            name  => $name,
            types => \%classes
        );
    }
    \%namespaces;
}

#===================================
sub _build_doc_class_wrappers {
#===================================
    my $self       = shift;
    my $namespaces = $self->meta->namespaces;
    +{  map { $_ => $self->wrap_doc_class($_) }
        map { values %$_ } values %{ $self->meta->namespaces }
    };
}

#===================================
sub _build_index_namespace {
#===================================
    my $self    = shift;
    my $domains = $self->meta->domains;

    my %namespaces;
    push @{ $namespaces{ $domains->{$_} } }, $_ for keys %$domains;

    my %index;

    for my $name ( keys %namespaces ) {
        my $aliases = $self->es->get_aliases( index => $namespaces{$name} );
        my @names = uniq @{ $namespaces{$name} },
            map { $_, keys %{ $aliases->{aliases} } }
            keys %$aliases;
        my $ns = $self->get_namespace($name);
        for (@names) {
            croak "Cannot map index/alias ($_) to namespace ($ns). "
                . "It is already mapped to namespace ($index{$_})"
                if $index{$_} && refaddr $index{$_} ne refaddr $ns;
            $index{$_} = $ns;
        }
    }
    \%index;
}

#===================================
sub namespace_for_index {
#===================================
    my ( $self, $index ) = @_;
    my $ns;
    $ns = $self->_get_index_namespace($index) and return $ns;
    $self->_clear_index_namespace;
    $self->_get_index_namespace($index)
        or croak "No namespace found for index ($index). ";
}

#===================================
sub wrap_doc_class {
#===================================
    my $self  = shift;
    my $class = shift;

    load_class($class);

    croak "Class ($class) does not do Elastic::Model::Role::Doc. "
        . "Please add : use Elastic::Doc;\n\n"
        unless Moose::Util::does_role( $class, 'Elastic::Model::Role::Doc' );

    my $new_class = $self->meta->wrapped_class_name($class);
    my $meta
        = Moose::Meta::Class->create( $new_class, superclasses => [$class] );
    $meta->_set_original_class($class);
    $meta->_set_model($self);

    weaken( my $weak_model = $self );
    $meta->add_method( model          => sub {$weak_model} );
    $meta->add_method( original_class => sub {$class} );
    $meta->make_immutable;

    return $meta->name;
}

#===================================
sub wrap_class {
#===================================
    my $self  = shift;
    my $class = shift;

    load_class($class);

    my $meta = Moose::Meta::Class->create(
        $self->meta->wrapped_class_name($class),
        superclasses => [$class],
        weaken       => 0,
    );

    $meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $meta,
        class_metaroles => { class => ['Elastic::Model::Meta::Class'], }
    );

    $meta->_set_original_class($class);
    $meta->_set_model($self);

    weaken( my $weak_model = $self );
    $meta->add_method( model          => sub {$weak_model} );
    $meta->add_method( original_class => sub {$class} );

    $meta->make_immutable;
    return $meta->name;
}

#===================================
sub domain {
#===================================
    my $self = shift;
    my $name = shift or croak "No domain name passed to domain()";
    my $domain;

    $domain = $self->_get_domain($name) and return $domain;

    my $ns_name = $self->meta->domain($name)
        or croak "Unknown domain name ($name)";

    my $ns = $self->get_namespace($ns_name)
        or croak "Unknown namespace ($ns_name)";

    $domain = $self->domain_class->new(
        name      => $name,
        namespace => $ns
    );
    return $self->_cache_domain( $name => $domain );
}

#===================================
sub view { shift->view_class->new(@_) }
#===================================

#===================================
sub new_scope {
#===================================
    my $self = shift;
    my @args
        = $self->has_current_scope ? ( parent => $self->current_scope ) : ();
    $self->current_scope( $self->scope_class->new(@args) );
}

#===================================
sub detach_scope {
#===================================
    my ( $self, $scope ) = @_;
    my $current = $self->current_scope;
    return unless $current && refaddr($current) eq refaddr($scope);
    my $parent = $scope->parent;
    return $self->clear_current_scope unless $parent;
    $self->current_scope($parent);
}

#===================================
sub get_doc {
#===================================
    my ( $self, $uid, $source ) = @_;
    croak "No UID passed to get_doc()" unless $uid;

    my $ns    = $self->namespace_for_index( $uid->index );
    my $scope = $self->current_scope;

    my $object;
    $object = $scope->get_object( $ns, $uid ) unless $source;

    unless ($object) {
        $source ||= $self->get_doc_source($uid) unless $uid->from_store;
        my $class = $ns->class_for_type( $uid->type );
        $object = $class->meta->new_stub( $uid, $source );
        $object = $scope->store_object( $ns->name, $object );
    }
    $object;
}

#===================================
sub get_doc_source {
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
    my $ns     = $self->namespace_for_index( $uid->index );
    my $action = $uid->from_store ? 'index_doc' : 'create_doc';
    my $data   = $self->deflate_object($doc);
    my $result = $self->store->$action( $uid, $data, \%args );
    $uid->update_from_store($result);
    return $self->current_scope->store_object( $ns->name, $doc );
}

#===================================
sub delete_doc {
#===================================
    my $self   = shift;
    my $doc    = shift;
    my %args   = ref $_[0] ? %{ shift() } : @_;
    my $uid    = $doc->uid;
    my $ns     = $self->namespace_for_index( $uid->index );
    my $result = $self->store->delete_doc( $doc->uid, \%args );
    $uid->update_from_store($result);
    return $self->current_scope->delete_object( $ns->name, $doc );
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
    $class = $self->class_for($class) || $class;
    return $self->deflators->{$class} ||= do {
        die "Class $class is not an Elastic class."
            unless does_role( $class, 'Elastic::Model::Role::Doc' );
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
    $class = $self->class_for($class) || $class;
    return $self->inflators->{$class} ||= do {
        die "Class $class is not an Elastic class."
            unless does_role( $class, 'Elastic::Model::Role::Doc' );
        $self->type_map->class_inflator($class);
    };
}

#===================================
sub map_class {
#===================================
    my $self  = shift;
    my $class = shift;
    $class = $self->class_for($class) || $class;

    die "Class $class is not an Elastic class."
        unless does_role( $class, 'Elastic::Model::Role::Doc' );

    my $meta = $class->original_class->meta;

    my %mapping = (
        %{ $meta->type_mapping },
        $self->type_map->class_mapping($class),
        dynamic           => 'strict',
        _timestamp        => { enabled => 1, path => 'timestamp' },
        numeric_detection => 1,
    );

    $mapping{_source}{compress} = 1;
    return \%mapping;
}

1;

__END__

# ABSTRACT: The role applied to your Model

=head1 SYNOPSIS

    use MyApp;

    my $es     = ElasticSearch->new( servers => 'es.domain.com:9200' );
    my $model  = MyApp->new( es => $es );

    my $domain = $model->domain('my_domain');
    my $users  = $model->view->type('user');

    my $scope  = $model->new_scope;

    # do stuff with your model


=head1 DESCRIPTION

C<Elastic::Model::Role::Model> is applied to your Model class when you
include the line:

    use Elastic::Model;

See L<Elastic::Model> for more about how to setup your Model class.

=head1 COMMONLY USED METHODS

=head2 new()

Usually, the only parameter that you need to pass to C<new()> is C<es>,
which contains your L<ElasticSearch> connection.

    $es    = ElasticSearch->new( servers => 'es1.domain.com:9200' );
    $model = MyApp->new( es => $es );

If the C<es> parameter is omitted, then it will default to an L<ElasticSearch>
connection to C<localhost:9200>.

    $model = MyApp->new();   # localhost:9200

If you want to use a different TypeMap than L<Elastic::Model::TypeMap::Default>,
then you can do:

    $model = MyApp->new(
        es        => $es,
        type_map  => 'MyApp::TypeMap'
    );

See L</"Overriding Core Classes"> for more parameters that can be passed to
L</"new()">.

=head2 domain()

    $domain = $model->domain($name);

Returns an L<Elastic::Model::Domain> instance corresponding to the C<$name>,
which can be the L<Elastic::Model::Domain/"name">, a
L<Elastic::Model::Domain/"sub_domain">, one of the
L<Elastic::Model::Domain/"archive_indices"> or any alias or index that
is aliased to any listed domain name, sub-domain name or archive-index.

=head2 new_scope()

    $scope = $model->new_scope();

Creates a new L<scope|Elastic::Model::Scope> (in-memory cache). If there is an
existing scope, then the new scope inherits from the existing scope.

    $scope = $model->new_scope();   # scope_1
    $scope = $model->new_scope();   # scope_2, inherits from scope_1
    undef $scope;                   # scope_2 and scope_1 are destroyed

See L<Elastic::Model::Scope> to read more about how scopes work.

=head2 view()

    $view = $model->view(%args);

Creates a new L<view|Elastic::Model::View>. Any args are passed on to
L<Elastic::Model::View/"new()">.


=head1 OTHER METHODS AND ATTRIBUTES

These methods and attributes, while public, are usually used only by internal
modules. They are documented here for completeness.

=head2 Miscellaneous

=head3 domain_for_index()

    $domain = $model->domain_for_index($index_name)

Returns the L<Elastic::Model::Domain> object which corresponds to the
C<$index_name>.  If the index (or alias) name is not yet known to the
C<$model>, it will query ElasticSearch for index/alias information.

=head3 es

    $es = $model->es

Returns the L<ElasticSearch> instance that was passed to L</"new()">.

=head3 store

    $store = $model->store

Returns the L<Elastic::Model::Store> instance.

=head2 CRUD

=head3 get_doc()

Normally, you want to use L<Elastic::Model::Domain/"get()"> rather than this
method.

    $doc = $model->get_doc($uid);

C<get_doc()> tries to retrieve the object corresponding to the
L<$uid|Elastic::Model::UID>, first from the current
L<scope|Elastic::Model::Scope> or any of its parents, then failing that,
from the L<store|Elastic::Model::Store>. If it finds the doc, then
it stores it in the current scope, otherwise it throws an error.

C<get_doc()> also accepts a second optional C<$source> parameter which is
used internally for inflating search results.

See L<Elastic::Model::Scope> for a more detailed explanation.

=head3 get_doc_source()

    $doc = $model->get_doc_source($uid)

Calls L<Elastic::Model::Store/"get_doc()"> and returns the raw source hashref
as stored in ElasticSearch for the doc with the corresponding
L<$uid|Elastic::Model::UID>. Throws an error if it doesn't exist.

=head3 save_doc()

Normally, you want to use L<Elastic::Model::Role::Doc/"save()"> rather than this
method.

    $doc = $domain->save_doc($doc,%args);

Saves C<$doc> to ElasticSearch by calling
L<Elastic::Model::Store/"index_doc()"> (if the C<$doc> was originally loaded
from ElasticSearch), or L<Elastic::Model::Store/"create_doc()">, which
will throw an error if a doc with the same L<$uid|Elastic::Model::UID> already
exists.

Any C<%args> are passed on to L<index_doc()|Elastic::Model::Store/"index_doc()"> or
L<create_doc()|Elastic::Model::Store/"create_doc()">.

=head3 delete_doc()

TODO: Currently not working

=head3 search()

Normally, you want to use L<Elastic::Model::View> rather than this
method.

    $results = $model->search(%args)

Passes C<%args> through to L<Elastic::Model::Store/"search()">

=head2 Deflation, Inflation And Mapping

=head3 deflator_for_class()

    $deflator = $model->deflator_for_class($class);

Returns a code-ref that knows how to deflate a class which does
L<Elastic::Model::Role::Doc>, and caches the deflator in L</"deflators">.

=head3 deflate_object()

    $hash = $model->deflate_object($object);

Uses the deflator returned by L</"deflator_for_class()"> to deflate
an object which does L<Elastic::Model::Role::Doc> into a hash ref
suitable for conversion to JSON.

=head3 deflators

    $deflators = $model->deflators

A hashref which caches all of the deflators which have been generated by
L</"deflator_for_class()">.

=head3 inflator_for_class()

    $inflator = $model->inflator_for_class($class);

Returns a code-ref that knows how to inflate a plain hashref into the correct
attribute values for a class which does L<Elastic::Model::Role::Doc>,
and caches the inflator in L</"inflators">.

=head3 inflate_object()

    $object = $model->inflate_object($object,$hash);

Uses the inflator returned by L</"inflator_for_class()"> to inflate
the attribute values of C<$object> from the value stored in C<$hash>.

=head3 inflators

    $inflators = $model->inflators

A hashref which caches all of the inflators which have been generated by
L</"inflator_for_class()">.

=head3 map_class()

    $mapping = $model->map_class($class);

Returns the type mapping / schema for a class which does
L<Elastic::Model::Role::Doc>, suitable for passing to ElasticSearch.

=head2 Scoping

Also see L</"new_scope()"> and L<Elastic::Model::Scope>.

=head3 current_scope()

    $scope = $model->current_scope($scope);

Read/write accessor for the current scope. Throws an exception if no scope
is currently set.

=head3 detach_scope()

    $model->detach_scope($scope);

Removes the passed in C<$scope> if it is the current scope. Replaces
the current scope with its parent scope, if there is one. L</"detach_scope()">
is called automatically when a scope goes out of scope:

    {
        my $scope = $model->new_scope;
        # do work
    }
    # current scope is removed

=head3 has_current_scope()

    $bool = $model->has_current_scope

Returns a true or false value signalling whether a L</"current_scope()">
exists.

=head3 clear_current_scope()

    $model->clear_current_scope

Clears the L</"current_scope()">

=head2 Overriding Core Classes

If you would like to override any of the core classes used by L<Elastic::Model>,
then you can pass the new class name as a parameter to L</"new()">.

The class you are most likely to override is the
L<type_map|Elastic::Model::TypeMap::Default>, in order to define your own
deflators, inflators and mappings.

=head3 Default core classes

=over

=item *

C<type_map> C<------------------> L<Elastic::Model::TypeMap::Default>

=item *

C<domain_class> C<--------------> L<Elastic::Model::Domain>

=item *

C<store_class> C<---------------> L<Elastic::Model::Store>

=item *

C<view_class> C<----------------> L<Elastic::Model::View>

=item *

C<scope_class> C<---------------> L<Elastic::Model::Scope>

=item *

C<results_class> C<-------------> L<Elastic::Model::Results>

=item *

C<scrolled_results_class> C<----> L<Elastic::Model::Results::Scrolled>

=item *

C<result_class> C<--------------> L<Elastic::Model::Result>

=back

These classes are L<wrapped|/"wrap_class()"> to pin them to the current
C<$model> and the wrapped class names are accessible via methods of the same
name, eg:

    $wrapped_class = $model->type_map;
    $wrapped_class = $model->scope_class;

=head3 wrap_class()

    $wrapped_class = $model->wrap_class($class)

Wraps a class in an anonymous class and stores the current C<$model> in
the wrapped class' metaclass, allowing a class to do:

    $model = $wrapped_class->model
    $class = $wrapped_class->meta->original_class;

=head3 wrap_doc_class()

Like L</"wrap_class()">, but specifically for classes which do
L<Elastic::Model::Role::Doc>. It doesn't add C<model()> to the wrapped
class. Instead, that class can access the C<$model> by doing:

    $model = $wrapped_class->meta->model

=head3 doc_class_wrappers

    $wrapped_classes = $model->doc_class_wrappers

A hashref of all wrapped doc classes (ie those classes which do
L<Elastic::Model::Role::Doc>). The keys are the original class names, and
the values are the wrapped class names.

=head3 class_for()

    $wrapped_class = $model->class_for($class);

Returns the name of the wrapped class which corresponds to C<$class>.

=head3 known_class()

    $bool = $model->known_class($class);

Returns a true or false value to signal whether doc C<$class> has been wrapped.

