package ESModel::Index;

use Carp;
use Moose;
with 'ESModel::Role::ModelAttr';
use MooseX::Types::Moose qw(:all);

has 'name' => (
    isa      => Str,
    is       => 'rw',
    required => 1,
);

has 'settings' => (
    isa     => HashRef,
    is      => 'rw',
    default => sub { {} },
);

has 'types' => (
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

no Moose;

# TODO: create_as ? do we clone?
#===================================
sub create {
#===================================
    my $self     = shift;
    my $mappings = $self->mappings();
    my %settings = (
        %{ $self->settings },
        $self->model->meta->analysis_for_mappings($mappings)
    );
    my $model = $self->model;
    $model->_clear_live_indices;
    $model->es->create_index(
        index    => $self->name,
        mappings => $mappings,
        settings => \%settings,
    );
    return $self;
}

#===================================
sub alias_to {
#===================================
    my $self    = shift;
    my @indices = ref $_[0] ? @{ shift() } : @_;
    my $name    = $self->name;
    my $model   = $self->model;
    $model->_clear_live_indices;
    $model->es->aliases( actions =>
            [ map { +{ add => { alias => $name, index => $_ } } } @indices ]
    );
    return $self;
}

#===================================
sub delete {
#===================================
    my $self   = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    my $model  = $self->model;
    $model->_clear_live_indices;
    $model->es->delete_index( %params, index => $self->name );
    return $self;
}

#===================================
sub exists {
#===================================
    my $self = shift;
    !!$self->model->es->index_exists( index => $self->name );
}

#===================================
sub refresh {
#===================================
    my $self = shift;
    $self->model->es->refresh_index( index => $self->name );
    return $self;
}

#===================================
sub put_mapping {
#===================================
    my $self     = shift;
    my $mappings = $self->mappings(@_);
    my $index    = $self->name;
    my $es       = $self->model->es;
    for my $type ( keys %$mappings ) {
        $es->put_mapping(
            index   => $index,
            type    => $type,
            mapping => $mappings->{$type}
        );
    }
    return $self;
}

#===================================
sub delete_mapping {
#===================================
    my $self  = shift;
    my $index = $self->name;
    my $es    = $self->model->es;
    for ( ref $_[0] ? @{ shift() } : @_ ) {
        $es->delete_mapping( index => $index, type => $_ );
    }
    return $self;
}

#===================================
sub update_settings {
#===================================
    my $self = shift;
    my %settings = ( %{ $self->settings }, ref $_[0] ? %{ shift() } : @_ );
    $self->update_index_settings(
        index    => $self->name,
        settings => \%settings
    );
    return $self;
}

#===================================
sub open {
#===================================
    my $self  = shift;
    my $model = $self->model;
    $model->_clear_live_indices;
    $model->es->open_index( index => $self->name );
    return $self;
}

#===================================
sub close {
#===================================
    my $self  = shift;
    my $model = $self->model;
    $model->_clear_live_indices;
    $model->es->close_index( index => $self->name );
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

1;
