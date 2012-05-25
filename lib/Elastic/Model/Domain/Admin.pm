package Elastic::Model::Domain::Admin;

use Moose;
use MooseX::Types::Moose qw(Str);
use Carp;
use namespace::autoclean;

#===================================
has 'domain' => (
#===================================
    is       => 'ro',
    isa      => 'Elastic::Model::Domain',
    required => 1,
    handles  => [ 'name', 'es' ]
);

no Moose;

#===================================
sub create_index {
#===================================
    my $self   = shift;
    my $params = $self->_index_config(@_);

    $self->es->create_index($params);
    return $self;
}

#===================================
sub _index_config {
#===================================
    my $self     = shift;
    my $settings = $self->_parse_index_params(@_);

    my $index    = delete $settings->{index};
    my $mappings = $self->mappings();
    my $analysis = $self->model->meta->analysis_for_mappings($mappings);

    return {
        index    => $index,
        settings => { %$settings, analysis => $analysis },
        mappings => $mappings
    };
}

#===================================
sub _parse_index_params {
#===================================
    my $self = shift;
    my $name = @_ % 2 ? shift() : $self->name;
    return { index => $name, @_ };
}

#===================================
sub _index_action {
#===================================
    my $self   = shift;
    my $action = shift;
    my $params = $self->_parse_index_params(@_);
    $self->es->$action($params);
    return $self;
}

#===================================
sub delete  { shift->_index_action( 'delete_index',  @_ ) }
sub refresh { shift->_index_action( 'refresh_index', @_ ) }
sub open    { shift->_index_action( 'open_index ',   @_ ) }
sub close   { shift->_index_action( 'close_index ',  @_ ) }
#===================================

#===================================
sub exists {
#===================================
    my $self   = shift;
    my $params = $self->_parse_index_params(@_);
    !!$self->es->index_exists($params);
}

#===================================
sub update_settings {
#===================================
    my $self = shift;

    my $settings = $self->_parse_index_params(@_);
    my $index    = delete $settings->{index};

    $self->update_index_settings(
        index    => $index,
        settings => $settings
    );
    return $self;
}

#===================================
sub update_analysers {
#===================================
    my $self   = shift;
    my $params = $self->_index_config(@_);
    delete $params->{mapping};
    $self->update_index_settings($params);
    return $self;
}

#===================================
sub alias_to {
#===================================
    my $self = shift;
    my @args = ref $_[0] ? @{ shift() } : @_;

    my $name = $self->name;
    my $es   = $self->es;

    my %indices = ( (
            map { $_ => { remove => { index => $_, alias => $name } } }
                keys %{ $es->get_aliases( index => $name ) }
        ),
        $self->_add_aliases(@args)
    );

    $es->aliases( actions => [ values %indices ] );
    $self->domain->clear_default_routing;
    return $self;
}

#===================================
sub delete_alias { shift->alias_to() }
#===================================

#===================================
sub add_to_alias {
#===================================
    my $self    = shift;
    my @args    = ref $_[0] ? @{ shift() } : @_;
    my %indices = $self->_add_aliases(@args);
    $self->es->aliases( actions => [ values %indices ] );
    $self->domain->clear_default_routing;
    return $self;
}

#===================================
sub remove_from_alias {
#===================================
    my $self    = shift;
    my $name    = $self->name;
    my @actions = map { { remove => { index => $_, alias => $name } } }
        ref $_[0] ? @{ shift() } : @_;
    $self->es->aliases( actions => \@actions );
    return $self;
}

#===================================
sub aliased_to {
#===================================
    my $self    = shift;
    my $name    = $self->name;
    my $indices = $self->es->get_aliases( index => $name );
    croak "($name) is an index, not an alias"
        if $indices->{$name};

    map { $_ => $indices->{$_}{aliases}{$name} } keys %$indices;
}

#===================================
sub is_alias {
#===================================
    my $self    = shift;
    my $name    = shift || $self->name;
    my $indices = $self->es->get_aliases( index => $name );
    return !!( %$indices && !$indices->{$name} );
}

#===================================
sub is_index {
#===================================
    my $self = shift;
    my $name = shift || $self->name;
    return !!$self->es->get_aliases( index => $name )->{$name};
}

#===================================
sub _add_aliases {
#===================================
    my $self = shift;
    my $name = $self->name;
    my $es   = $self->es;
    my %indices;

    while (@_) {
        my $index  = shift @_;
        my %params = (
            ref $_[0] ? %{ shift @_ } : (),
            index => $index,
            alias => $name
        );
        if ( my $filter = delete $params{filterb} ) {
            $params{filter} = $es->builder->filter($filter)->{filter};
        }
        $indices{$index} = { add => \%params };
    }
    return %indices;
}

#===================================
sub update_mapping {
#===================================
    my $self     = shift;
    my $name     = ref $_[0] eq 'ARRAY' ? $self->name : shift();
    my $mappings = $self->mappings( @{ shift() || [] } );
    my $es       = $self->es;
    for my $type ( keys %$mappings ) {
        $es->update_mapping(
            index   => $name,
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
    my $name  = ref $_[0] eq 'ARRAY' ? $self->name : shift();
    my $es    = $self->es;
    my @types = @{ shift() || [] };
    $es->delete_mapping( index => $name, type => $_ ) for @types;
    return $self;
}

#===================================
sub mappings {
#===================================
    my $self   = shift;
    my $domain = $self->domain;
    my $ns     = $domain->namespace;
    my @types
        = @_ == 0   ? $ns->all_types
        : ref $_[0] ? @{ shift() }
        :             @_;
    my $model = $domain->model;
    +{ map { $_ => $model->map_class( $ns->class_for_type($_) ) } @types };
}

1;

__END__

# ABSTRACT: Administer indices and aliases in ElasticSearch

=head1 SYNOPSIS

    $admin = $domain->admin;

=head2 Create an index

    $admin->create_index(%settings);
    $admin->create_index('foo',%settings);

=head2 Act on an index or alias

    $admin->delete();
    $admin->delete('foo');

    $admin->close();
    $admin->close('foo');

    $admin->open();
    $admin->open('foo');

    $admin->refresh();
    $admin->refresh('foo');

    $admin->update_mapping(@types);
    $admin->delete_mapping(@types);

    $admin->update_settings(%settings);
    $admin->update_settings('foo', %settings);


=head2 Create/change aliases

    $admin->alias_to('foo','bar');

    $admin->alias_to(
        foo => { routing => '1'},
        bar => { filterb => {
            client => 'new'
        }}
    );

    $admin->add_to_alias(
        'index_june',
        'index_july' => {
            routing => '1'
        }
    );

    $admin->remove_from_alias('index_old','index_older');

    $admin->delete_alias();

=head2 Information

    $indices = $admin->aliased_to;

    $bool    = $admin->is_index;
    $bool    = $admin->is_index('foo');

    $bool    = $admin->is_alias;
    $bool    = $admin->is_alias('foo');

    $bool    = $admin->exists;
    $bool    = $admin->exists('foo');

=head1 DESCRIPTION

L<Elastic::Model::Domain::Admin> objects are used to administer indices
and aliases in an ElasticSearch cluster.

First, some terminology: An L<index|Elastic::Manual::Terminology/Index> is
like a database in a relational DB.  An
L<alias|Elastic::Manual::Terminology/Alias> points to one or more indices.

=head2 A typical workflow

When making changes to an index, there are some changes (eg changing
a field type, or an analyzer) which can't be done on the same index. Instead,
you need to create a new index, and reindex your data from old to new.
But you don't want to have to change your index names in the application.
Aliases are very useful here: your application uses the alias name instead
of an index name; once you have reindexed your data to a new index, you
can just update the alias to point to the new index.

For example:

    $admin = $domain->admin();

    print $domain->name;
    # myapp

    print $admin->name;
    # myapp

    $admin->create_index( 'myapp_1' )
          ->alias_to( 'myapp_1' );

This has created the index C<myapp_1> and created the alias C<myapp> to
point to C<myapp_1>.

    $admin->create_index( 'myapp_2' );

    reindex_data_somehow();

    $admin->alias_to( 'myapp_2');
    $admin->delete( 'myapp_1' ):

This has created the index C<myapp_2>, updated the alias C<myapp> to point
to C<myapp_2> instead of C<myapp_1>, then deleted the no longer needed
index C<myapp_1>.

=head2 The index/alias name

Given the above work flow, it should be obvious that it is most useful for your
L<domain names|Elastic::Model::Domain/name> to be aliases.  This gives you
the most flexibility.

So, for the alias methods (L</alias_to()>, L</add_to_alias()>,
L</remove_from_alias()>, L</delete_alias()>), you can't specify a different
alias name.  It will always use the C<< $domain->name >>.

The L</create_index()> method only accepts an index name, not an alias name,
but it will default to the C<< $domain->name >> (easy for development, but
better to specify a different name, as per the work flow above).

The other methods (L</delete()>, L</refresh()>, L</open()>, L</close()>,
L</exists()> and L</update_mapping()>) can apply equally to an index or an alias,
so they will default to using the C<< $domain->name >>, but will accept
a different index/alias name as the first parameter.

=head1 ATTRIBUTES

=head2 domain

    $domain = $admin->domain;

Returns the L<Elastic::Model::Domain> object that was used to create the
C<$admin> object.

=head1 METHODS

Unless otherwise stated, all methods return the C<$admin> object, so that
methods can be chained:

    $admin->create_index('foo_2')->alias_to('foo_2')->delete('foo_1');

=head2 INDEX METHODS

=head3 create_index()

    $admin = $admin->create_index();
    $admin = $admin->create_index( $name );
    $admin = $admin->create_index( %settings );
    $admin = $admin->create_index( $name, %settings );

Creates an index called C<$name> (which defaults to C<< $domain->name >>).
The L<type mapping|Elastic::Manual::Terminology/Mapping> is automatically
generated from the attributes of your doc classes listed in the domain's
L<namespace|Elastic::Model::Domain/namespace>.  Similarly, any
L<custom analyzers|Elastic::Model/"Specifying custom analyzers"> required
by your classes are added to the index
L<%settings|http://www.elasticsearch.org/guide/reference/api/admin-indices-update-settings.html>
that you pass in:

    $admin->create_index('myapp_1', number_of_shards => 1);

=head2 ALIAS METHODS

Methods in this section use C<< $domain->name >> as the alias name - a different
alias name cannot be specified. If you want to specify a different alias
name, then add it to your domains in L<your model|Elastic::Model>.

=head3 alias_to()

    $admin = $admin->alias_to(@index_names);
    $admin = $admin->alias_to(
        index_name => \%alias_settings,
        ...
    );

Creates or updates the alias C<< $domain->name >> and sets it to point
to the listed indices.  If it already exists and points to indices not specified
in C<@index_names>, then those indices will be removed from the alias.

Aliases can have filters and routing values associated with an index, for
instance:

    $admin->alias_to(
        my_index => {
            routing => 'client_one',
            filterb => { client => 'client_one'}
        }
    );

See L< --TODO-- > for more.

=head3 add_to_alias()

    $admin = $admin->add_to_alias(@index_names);
    $admin = $admin->add_to_alias(
        index_name => \%alias_settings,
        ...
    );

L</add_to_alias()> works in the same way as L</alias_to()> except that
indices are only added - existing indices are not removed.

=head3 remove_from_alias()

    $admin = $admin->remove_from_alias(@index_names);

The listed index names are removed from alias C<< $domain->name >>.

=head3 delete_alias()

    $admin = $admin->delete_alias();

Deletes alias C<< $domain->name >>.

=head3 aliased_to()

    %indices = $admin->aliased_to();

Returns a hash suitable for passing to L</alias_to()>, whose keys are
index names, and whose values are the alias settings.

=head2 INDEX OR ALIAS METHODS

Methods in this section can work with index names or alias names.  They
default to using the C<< $domain->name >>, but accept a different index or
alias name as the first argument.

=head3 delete()

    $admin = $admin->delete();
    $admin = $admin->delete( $name );
    $admin = $admin->delete( %args );
    $admin = $admin->delete( $name, %args );

Deletes the index (or indices pointed to by alias ) C<$name> (which defaults to
C<< $domain->name >>). Any C<%args> are passed on to L<ElasticSearch/delete_index()>.
For example:

    $admin->delete('myapp_v2', ignore_missing => 1);

=head3 refresh()

    $admin = $admin->refresh();
    $admin = $admin->refresh( $name );

Forces the index (or indices pointed to by alias ) C<$name> (which defaults to
C<< $domain->name >>) to be refreshed, ie all changes to the docs in the index
become visible to search.  By default, indices are refreshed once every
second anyway. You shouldn't abuse this option as it will have a performance impact.

=head3 open()

    $admin = $admin->open();
    $admin = $admin->open( $name );

Opens the index (or the SINGLE index pointed to by alias ) C<$name> (which
defaults to C<< $domain->name >>).

=head3 close()

    $admin = $admin->close();
    $admin = $admin->close( $name );

Closes the index (or the SINGLE index pointed to by alias ) C<$name> (which
defaults to C<< $domain->name >>).

=head3 update_settings()

    $admin = $admin->update_settings( %settings );
    $admin = $admin->update_settings( $name, %settings );

Updates the L<index settings|http://www.elasticsearch.org/guide/reference/api/admin-indices-update-settings.html>
for the index (or indices pointed to by alias ) C<$name> (which defaults to
C<< $domain->name >>).

For example, if you want to rebuild an index, you could disable refresh
until you are finished indexing:

    $admin->update_settings( 'new_index', refresh_interval => -1 );
    populate_index();
    $admin->update_settings( 'new_index', refresh_interval => '1s' );

=head3 update_analysers()

    $admin = $admin->update_analysers();
    $admin = $admin->update_analysers( $name );

Mostly, analysers can't be changed on an existing index, but new analyzers
can be added.  L</update_analysers()> will generate a new analyzer configuration
and try to update index (or the indices pointed to by alias) C<$name> (
which defaults to C<< $domain->name >>).


=head3 update_mapping()

    $admin = $admin->update_mapping();
    $admin = $admin->update_mapping( $name );
    $admin = $admin->update_mapping( \@type_names );
    $admin = $admin->update_mapping( $name, \@type_names );

Type mappings cannot be changed on an existing index, but they can be
added to.  L</update_mapping()> will generate a new type mapping from your
doc classes, and try to update index (or the indices pointed to by alias)
C<$name> (which defaults to C<< $domain->name >>).

You can optionally specify a list of types to update, otherwise it will
update all types known to your domain namespace.

    $admin->update_mapping( 'my_index', ['user','post']);

=head3 delete_mapping();

    $admin = $admin->delete_mapping( \@types );
    $admin = $admin->delete_mapping( $name, \@types );

Deletes the type mapping AND THE DOCUMENTS for the listed types in the index
(or the indices pointed to by alias) C<$name> (which defaults to
C<< $domain->name >>).

=head3 exists()

    $bool = $admin->exists();
    $bool = $admin->exists( $name );

Checks whether the index (or ALL the indices pointed to by alias ) C<$name> (which
defaults to C<< $domain->name >>).

=head3 is_alias()

    $bool = $admin->is_alias();
    $bool = $admin->is_alias( $name );

Checks if C<$name> (which defaults to C<< $domain->name >>) is an alias.

=head3 is_index()

    $bool = $admin->is_index();
    $bool = $admin->is_index( $name );

Checks if C<$name> (which defaults to C<< $domain->name >>) is an index.


=head2 OTHER METHODS

    $mapping = $admin->mapping(@types);

Generates the type mapping for the types specified in C<@types>, or for
all types known to the domain's namespace.
