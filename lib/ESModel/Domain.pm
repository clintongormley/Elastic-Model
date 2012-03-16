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
has 'archive_indices' => (
#===================================
    is  => 'ro',
    isa => ArrayRef [Str],
);

#===================================
has 'sub_domains' => (
#===================================
    is      => 'ro',
    isa     => ArrayRef [Str],
    default => sub { [] },
    lazy    => 1,
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
has 'routing' => (
#===================================
    isa       => Str,
    is        => 'ro',
    predicate => 'has_custom_routing'
);

#===================================
has '_default_routing' => (
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
    $self->model->view( index => $self->name, @_ );
}

#===================================
sub index {
#===================================
    my $self = shift;
    my $name = shift || $self->name;
    return ESModel::Domain::Index->new( domain => $self, name => $name );
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
