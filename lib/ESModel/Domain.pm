package ESModel::Domain;

use Carp;
use Moose;
use namespace::autoclean;
use ESModel::Domain::Index();
use MooseX::Types::Moose qw(:all);

#===================================
has 'name' => (
#===================================
    isa      => Str,
    is       => 'rw',
    required => 1,
);

#===================================
has 'settings' => (
#===================================
    isa     => HashRef,
    is      => 'rw',
    default => sub { {} },
);

#===================================
has 'types' => (
#===================================
    isa      => HashRef,
    traits   => ['Hash'],
    is       => 'ro',
    required => 1,
    handles  => {
        class_for_type => 'get',
        has_type       => 'exists',
        all_types      => 'keys',
    }
);

#===================================
has routing => (
#===================================
    isa       => Str,
    is        => 'ro',
    predicate => 'has_custom_routing'
);

#===================================
has _default_routing => (
#===================================
    isa     => Str,
    is      => 'ro',
    lazy    => 1,
    builder => '_get_default_routing',
);

#===================================
sub _get_default_routing {
#===================================
    my $self    = shift;
    my $name    = $self->name;
    my $aliases = $self->es->get_aliases( index => $name );

    croak "Domain ($name) doesn't exist either as an index or an alias"
        unless %$aliases;

    my @indices = keys %$aliases;
    croak "Domain ($name) is an alias pointing at more than one index: "
        . join( ", ", @indices )
        if @indices > 1;

    return $self->routing if $self->has_custom_routing;

    my $index = shift @indices;
    return '' if $index eq $name;
    return $aliases->{$index}{aliases}{$name}{index_routing} || '';
}

no Moose;

#===================================
sub new_doc {
#===================================
    my $self  = shift;
    my $type  = shift or croak "No type passed to new_doc";
    my $class = $self->class_for_type($type) or croak "Unknown type ($type)";

    my %params = ref $_[0] ? %{ shift() } : @_;

    my $uid = ESModel::UID->new(
        index   => $self->name,
        type    => $type,
        routing => $self->_default_routing,
        %params
    );

    return $class->new( %params, uid => $uid, );
}

#===================================
sub create { shift->new_doc(@_)->save }
#===================================

#===================================
sub get {
#===================================
    my $self = shift;
    my $type = shift or croak "No type passed to get()";
    my $id   = shift or croak "No id passed to get()";
    my $uid  = ESModel::UID->new(
        index   => $self->name,
        type    => $type,
        id      => $id,
        routing => $self->_default_routing,
    );
    $self->model->get_doc($uid);
}

#===================================
sub view {
#===================================
    my $self = shift;
    $self->model->view->domain( $self->name );
}

#===================================
sub index {
#===================================
    my $self = shift;
    my $name = shift || $self->name;
    return ESModel::Domain::Index->new( domain => $self, name => $name );
}

#===================================
sub alias_to {
#===================================
    my $self    = shift;
    my $indices = ref $_[0] ? shift() : [@_];
    my %indices = map { $_ => 1 } ref $_[0] ? @{ shift() } : @_;

    my $es      = $self->es;
    my $name    = $self->name;
    my $current = $es->get_aliases( index => $name )->{aliases}{$name};
    my @remove;
    @remove = grep { !$indices{$_} } @$current if $current;

    my @actions
        = map { +{ add => { alias => $name, index => $_ } } } keys %indices;
    push @actions,
        map { +{ remove => { alias => $name, index => $_ } } } @remove;
    $es->aliases( actions => \@actions );
    return $self;
}

#===================================
sub mappings {
#===================================
    my $self = shift;
    my @types
        = @_ == 0   ? $self->all_types
        : ref $_[0] ? @{ shift() }
        :             @_;
    my $model = $self->model;
    +{ map { $_ => $model->map_class( $self->class_for_type($_) ) } @types };
}

#===================================
sub es { shift->model->es }
#===================================

1;
