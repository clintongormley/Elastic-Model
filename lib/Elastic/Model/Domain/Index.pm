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
    return $self->es->mapping( index => $index, type => $types );
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

__END__

# ABSTRACT: Index/Alias administration

=head1 SYNOPSIS

    $index = $domain->index($name);
    $index = $domain->index();      # $domain->name

    $index->create;
    $index->delete;
    $bool = $index->exists;

    $index->alias_to(@indices);

    $index->put_mapping(@types);
    $index->put_mapping();          # all types
    $index->delete_mapping(@types);
    $mapping = $index->get_mapping;

    $index->update_settings();

    $index->open();
    $index->close();

=head1 DESCRIPTION

L<Elastic::Model::Domain::Index> is used for administering indices and aliases
in ElasticSearch.  You create an L<Elastic::Model::Domain::Index> instance
by calling:

    $domain->index($name);
  OR
    $domain->index();       # $name is $domain->name;

=head1 ATTRIBUTES

=head2 name

The name of the index or alias.  This defaults to the C<< $domain->name >> if
not specified.

=head2 domain

An instance of the L<$domain|Elastic::Model::Domain> used to create the
index.

=head1 METHODS

=head1 create()

    $index->create;

Creates an index with L</"name">, with any L<Elastic::Model::Domain/"settings">
specified in the domain, and with mappings for all the L<Elastic::Model::Domain/"types">
in your domain. Throws an exception if it did not complete successfully.

=head1 delete()

    $index->delete;

Deletes the index (or the indices associated with an alias), or throws an
exception if the index didn't exist. To avoid the index-missing exception, you
can call:

    $index->delete(ignore_missing => 1);

=head1 exists()

    $bool = $index->exists;

Returns a true/false value if indicating whether or not the index or alias exists.

=head1 alias_to()

    $index->alias_to(@index_names);

Creates a new alias (or updates an existing alias) pointing to the new list
of indices. If the alias already points to other indices, then these are
removed from the alias.

=head1 put_mapping()

    $index->put_mapping();
    $index->put_mapping(@types);

Updates the mapping for C<@types>, or if not specified, for all types known to
the L</"domain">.

B<NOTE:> You cannot CHANGE the mapping for a type, only add to it.  If you need
to change the mapping, then you will need to reindex your data to a new index
with the desired mapping, or delete the type (plus all data belonging to that
type).

=head1 delete_mapping()

    $index->delete_mapping(@types);

Deletes the mapping for the specified types.

=head1 get_mapping()

    $mapping = $index->get_mapping();

Returns the current mapping for all types for the index C<< $domain->name >>
or, if that is an alias, for all indices that it points to.

=head1 refresh()

    $index->refresh()

Forces the index to be refreshed, which makes all results visible to search.
By default, an index is auto-refreshed every second. While you can force
a refresh, you don't want to do it too often as it will impact performance.

=head1 open()

    $index->open;

Opens a closed index.

=head1 close()

    $index->close

Closes an open index

=head1 update_settings()

    $index->update_settings(%settings);

Updates the index settings, using the default L<Elastic::Model::Domain/"settings">
plus any additional settings that you pass in.  For instance, you may want
to disable refreshing temporarily:

    $index->update_settings( refresh_interval => 0 );







