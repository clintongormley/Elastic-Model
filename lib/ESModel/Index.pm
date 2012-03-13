package ESModel::Index;

use Carp;
use Moose;
use namespace::autoclean;

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
    $self->model->_clear_live_indices;
    $self->es->create_index(
        index    => $self->name,
        mappings => $mappings,
        settings => \%settings,
    );
    return $self;
}

#===================================
sub alias_to {
#===================================
    my $self = shift;
    my %indices = map { $_ => 1 } ref $_[0] ? @{ shift() } : @_;

    my $es      = $self->es;
    my $name    = $self->name;
    my $current = $es->get_aliases( index => $name )->{aliases}{$name};
    my @remove  = grep { !$indices{$_} } @$current if $current;

    my @actions
        = map { +{ add => { alias => $name, index => $_ } } } keys %indices;
    push @actions,
        map { +{ remove => { alias => $name, index => $_ } } } @remove;
    $es->aliases( actions => \@actions );

    $self->model->_clear_live_indices;
    return $self;
}

#===================================
sub delete {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    $self->model->_clear_live_indices;
    $self->es->delete_index( %params, index => $self->name );
    return $self;
}

#===================================
sub exists {
#===================================
    my $self = shift;
    !!$self->es->index_exists( index => $self->name );
}

#===================================
sub refresh {
#===================================
    my $self = shift;
    $self->es->refresh_index( index => $self->name );
    return $self;
}

#===================================
sub put_mapping {
#===================================
    my $self     = shift;
    my $mappings = $self->mappings(@_);
    my $index    = $self->name;
    my $es       = $self->es;
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
    my $es    = $self->es;
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
    my $self = shift;
    $self->model->_clear_live_indices;
    $self->es->open_index( index => $self->name );
    return $self;
}

#===================================
sub close {
#===================================
    my $self = shift;
    $self->model->_clear_live_indices;
    $self->es->close_index( index => $self->name );
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
