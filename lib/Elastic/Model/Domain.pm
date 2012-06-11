package Elastic::Model::Domain;

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
has 'namespace' => (
#===================================
    is       => 'ro',
    isa      => 'Elastic::Model::Namespace',
    required => 1,
    handles  => ['class_for_type'],
);

#===================================
has '_default_routing' => (
#===================================
    isa => Maybe [Str],
    is => 'ro',
    lazy    => 1,
    builder => '_get_default_routing',
    clearer => 'clear_default_routing',
);

no Moose;

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

    my $index = shift @indices;
    return '' if $index eq $name;
    return $aliases->{$index}{aliases}{$name}{index_routing} || '';
}

#===================================
sub new_doc {
#===================================
    my $self  = shift;
    my $type  = shift or croak "No type passed to new_doc";
    my $class = $self->class_for_type($type) or croak "Unknown type ($type)";

    my %params = ref $_[0] ? %{ shift() } : @_;

    my $uid = Elastic::Model::UID->new(
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
    my $uid  = Elastic::Model::UID->new(
        index   => $self->name,
        type    => $type,
        id      => $id,
        routing => $self->_default_routing,
    );
    $self->model->get_doc($uid);
}

#===================================
sub delete {
#===================================
    my $self = shift;

    # TODO: delete-by-id
}

#===================================
sub view {
#===================================
    my $self = shift;
    $self->model->view( index => $self->name, @_ );
}

#===================================
sub es { shift->model->es }
#===================================

1;

__END__

# ABSTRACT: The domain (index or alias) where your docs are stored.

=head1 SYNOPSIS

Get a domain instance:

    $domain = $model->domain('myapp');

Create a new doc/object

    $user = $domain->new_doc( user => \%args );
    $user->save;

    # or:

    $user = $domain->create( user => \%args);

Retrieve a doc by ID:

    $user = $domain->get( $type => $id )

Create a view on the current domain:

    $view = $domain->view(%args);

=head1 DESCRIPTION

A "domain" is an L<index|Elastic::Manual::Terminology/Index> or an
L<alias|Elastic::ManuaL::Terminology/Alias> (which points to one or more
indices). You use a domain to create new docs/objects or to retrieve
docs/obects by C<type>/C<id>.

B<NOTE:> You can only create a doc in a domain that is either a single index,
or an alias which points to a single index.

=head1  ATTRIBUTES

=head2 name

A domain name must be the name of an index, or an index alias.

=head2 namespace

An L<Elastic::Model::Namespace> object which maps
L<types|Elastic::Manual::Terminology/Type> to your doc classes.

=head2 es

    $es = $domain->es

Returns the connection to ElasticSearch.

=head1 INSTANTIATOR

=head2 new()

    $domain = $model->domain_class->new({
        name            => $domain_name,
        namespace       => $namespace,
    });

Although documented here, you shouldn't need  to call C<new()> yourself.
Instead you should use L<Elastic::Model::Role::Model/"domain()">:

    $domain = $model->domain($domain_name);

=head1 METHODS

=head2 new_doc()

    $doc = $domain->new_doc( $type => \%args );

C<new_doc()> will create a new object in the class that maps to type C<$type>,
passing C<%args> to C<new()> in the associated class. For instance:

    $user = $domain->new_doc( user => { name => 'Clint' });

=head2 create()

    $doc = $domain->create( $type => \%args );

This is the equivalent of:

    $doc = $domain->new_doc( $type => \%args )->save();

=head2 get()

    $doc = $domain->get( $type => $id );

Retrieves a doc of type C<$type> with ID C<$id> from index C<< $domain->name >>
or throws an exception if the doc doesn't exist.

=head2 view()

    $view = $domain->view(%args)

Creates a L<view|Elastic::Model::View> with the L<Elastic::Model::View/"index">
set to C<< $domain->name >>.  A C<view> is used for searching docs in a
C<$domain>.

