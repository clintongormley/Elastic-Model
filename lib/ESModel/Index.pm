package ESModel::Index;

use Moose;
use ESModel::Types qw(ES);

has 'model' => (
    does     => 'ESModel::Role::Model',
    is       => 'ro',
    required => 1,
);

has 'name' => (
    isa      => 'Str',
    is       => 'rw',
    required => 1,
);

has 'settings' => (
    isa     => 'HashRef',
    is      => 'rw',
    default => sub { {} },
);

has 'types' => (
    isa      => 'HashRef',
    traits   => ['Hash'],
    is       => 'ro',
    required => 1,
    handles  => {
        class_for_type => 'get',
        has_type       => 'exists',
        all_types      => 'keys',
    }
);

has 'es' => (
    isa     => ES,
    is      => 'ro',
    default => sub { shift->model->es }
);

no Moose;

#===================================
sub create {
#===================================
    my $self     = shift;
    my $mappings = $self->mappings();
    my %settings = (
        %{ $self->settings },
        $self->model->meta->analysis_for_mappings($mappings)
    );
    $self->es->create_index(
        index    => $self->name,
        mappings => $mappings,
        settings => \%settings,
    );
    return $self;
}

#===================================
sub delete {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
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
    $self->es->open_index( index => $self->name );
    return $self;
}

#===================================
sub close {
#===================================
    my $self = shift;
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
    return { map { $_ => $self->class_for_type($_)->meta->mapping } @types };
}

1;
