package Elastic::Model::Domain;

use Carp;
use Moose;
use namespace::autoclean;
use Elastic::Model::Domain::Index();
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
has '_default_routing' => (
#===================================
    isa => Maybe [Str],
    is => 'ro',
    lazy    => 1,
    builder => '_get_default_routing',
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
    return Elastic::Model::Domain::Index->new(
        domain => $self,
        name   => $name,
    );
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

__END__

# ABSTRACT: The domain (index or alias) where your docs are stored.

=head1 SYNOPSIS

=head1 DESCRIPTION

A "domain" is the logical namespace to which your docs belong. In the simplest
case, a domain maps to a single index in ElasticSearch. However, domains allow
you to combine multiple indices and index aliases in a single namespace.

=over

=item *

The domain knows how your doc classes map to the types stored in ElasticSearch.
For example any C<user> type in the indices that belong to a domain will be
handled by your C<MyApp::User> class (assuming that's how you configured it).

=item *

A domain name MUST be an index or an index alias which points to a single
index.

=item *

A domain may have several sub-domains, where a sub-domain can be an
index or an index alias which points to a single index.

=item *

A domain or sub-domain may point to an alias which includes a
L<default routing value|http://www.elasticsearch.org/guide/reference/api/admin-indices-aliases.html>
 - this routing value will be automatically applied to new docs.

=item *

A domain may also specify a number of L</"archive_indices"> which may be index
names or index aliases pointing to one or more indices.  These need to be
specified so that your model knows which domain should be used for docs
retrieved from these indices.

=back

=head1  ATTRIBUTES

=head2 name

A domain name must be the name of an index, or an index alias which points
to a SINGLE index.

=head2 sub_domains

A domain can have multiple sub-domains, where each sub-domain is the name
of an index ( or an index alias which points to a SINGLE index).  Sub-domains
share the same L</"types"> as the parent domain.  Sub-domains are
particularly useful when using
L<filtered aliases|http://www.elasticsearch.org/guide/reference/api/admin-indices-aliases.html>.

=head2 archive_indices

A domain can have multiple archive indices, where each archive index is
an index name (or an index alias which can point to MULTIPLE indices).  Archive
indices are used to inform your Model of which domain (and thus which
L</"types">) should be used for docs stored in these indices. Archive indices
cannot be used for creating new docs, as they may point to multiple indices.

=head2 types

A hashref whose keys represent the C<type> names in ElasticSearch, and
whose values represent the class which is stored in that C<type>.  For instance

    {
        user    => 'MyApp::User',
        post    => 'MyApp::Post',
        comment => 'MyApp::Comment'
    }


has 'sub_domains' => (
sub _get_default_routing {
sub new_doc {
sub create { shift->new_doc(@_)->save }
sub get {
sub view {
sub index {
sub mappings {
sub es { shift->model->es }
has 'name' => (
has 'settings' => (


