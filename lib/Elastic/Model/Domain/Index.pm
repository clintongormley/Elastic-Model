package Elastic::Model::Domain::Index;

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
has 'domain' => (
#===================================
    isa      => 'Elastic::Model::Domain',
    is       => 'ro',
    required => 1,
    handles  => [ 'mappings', 'settings', 'model', 'es' ]
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
sub alias_to {
#===================================
    my $self = shift;
    my @args = ref $_[0] ? @{ shift() } : @_;

    my $name = $self->name;
    my $es   = $self->es;

    my %indices = map { $_ => { remove => { index => $_, alias => $name } } }
        keys %{ $es->get_aliases( index => $name ) };

    while (@args) {
        my $index  = shift @args;
        my %params = (
            ref $args[0] ? %{ shift @args } : (),
            index => $index,
            alias => $name
        );
        if ( my $filter = delete $params{filterb} ) {
            $params{filter} = $es->builder->filter($filter)->{filter};
        }
        $indices{$index} = { add => \%params };
    }

    $es->aliases( actions => [ values %indices ] );
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
sub get_mapping {
#===================================
    my $self  = shift;
    my $types = ref $_[0] ? shift : [@_];
    my $index = $self->name;
    my $es    = $self->es;
    return $self->es->mapping( index => $index, type => $types )->{$index};
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

1;
