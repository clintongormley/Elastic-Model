package Elastic::Model::Namespace;

use Moose;
use MooseX::Types::Moose qw(Str HashRef);
use namespace::autoclean;

#===================================
has 'name' => (
#===================================
    is       => 'ro',
    isa      => Str,
    required => 1
);

#===================================
has 'types' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    builder => '_build_types',
    handles => {
        class_for_type => 'get',
        all_types      => 'keys'
    },
);

no Moose;

__PACKAGE__->meta->make_immutable;

1;

__END__

# ABSTRACT: Class-to-type map

=head1 SYNOPSIS

    package MyApp;

    use Elastic::Model;

    namespace 'myapp', (
        types   => {
            user    => 'MyApp::User',
            post    => 'MyApp::Post',
        },
        domains => ['index_1', 'alias_1'...]
    );

    no Elastic::Model;

=head1 DESCRIPTION

L<Elastic::Model::Namespace> maps L<types|Elastic::Manual::Terminology/Type>
to your doc classes, eg C<MyApp::User> is stored as type C<user>.
Each L<domain|Elastic::Model::Domain> has a C<namespace>, and all documents
stored in that C<domain> (L<index|Elastic::Manual::Terminology/Index> or
alias L<alias|Elastic::Manual::Terminology/Alias>) are handled by
the same C<namespace>. A C<namespace>/C<type>/C<id> combination should be
unique across all indices associated with a namespace.

See L<Elastic::Model> and L<Elastic::Manual::Intro> for more about
namespaces.

=head1 ATTRIBUTES

=head2 name

    $name = $namespace->name

The C<name> of the namespace.  This name is used by L<Elastic::Model::Scope>
to cache objects in memory.  A C<namespace>/C<type>/C<id> combination should be
unique across all indices associated with a namespace.

=head2 types

    \%types = $namespace->types

Returns a hashref whose keys are the type names in ElasticSearch, and whose
values are wrapped doc classes, eg the class C<MyApp::User>
wrapped by L<Elastic::Role::Model/wrap_doc_class()>.

=head1 METHODS

=head2 class_for_type()

    $class = $namespace->class_for_type($type)

Returns the name of the wrapped class which handles type C<$type>.

=head2 all_types()

    @types = $namespace->all_types()

Returns all the C<type> names known to the namespace.
