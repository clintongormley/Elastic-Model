package Elastic::Model::TypeMap::Default;

use Elastic::Model::TypeMap::Base qw(
    Elastic::Model::TypeMap::Moose
    Elastic::Model::TypeMap::Structured
    Elastic::Model::TypeMap::Common
    Elastic::Model::TypeMap::Objects
    Elastic::Model::TypeMap::ES
);

1;

__END__

# ABSTRACT: The default type map used by Elastic::Model

=head1 DESCRIPTION

Moose's L<type constraints|Moose::Util::TypeConstraints> and introspection
allows Elastic::Model to figure out how to map your data model to the
ElasticSearch backend with the minimum of effort on your part.

What YOU need to do is: B<Be specific about the type constraint for each attribute.>

For instance,  if you have an attribute called C<count>, then specify the
type constraint C<< isa => 'Int' >>.
That way, we know how to define the field in ElasticSearch, and how to deflate
and inflate the value. If you were to assign C<count> the type constraint
C<PositiveInt>, although we don't know about that constraint, we do know
about C<Int>, from which C<PostiveInt> derives, so we could
still handle the field correctly.


Type maps are used to define:

=over

=item *

what mapping Elastic::Model will generate for each attribute when you
L<create an index|Elastic::Model::Domain::Index/"create()">
or L<update the mapping|Elastic::Model::Domain::Index/"put_mapping()"> of an
existing index.

=item *

how Elastic::Model will deflate and inflate each attribute when saving or
retrieving docs stored in ElasticSearch.

=back

=head1 BUILT-IN TYPE MAPS

L<Elastic::Model::Typemap::Default> loads the following type-maps:

=over

=item *

L<Elastic::Model::Typemap::Moose>

=item *

L<Elastic::Model::Typemap::Objects>

=item *

L<Elastic::Model::Typemap::Structured>

=item *

L<Elastic::Model::Typemap::ES>

=item *

L<Elastic::Model::Typemap::Common>

=back

=head1 DEFINING YOUR OWN TYPE MAP

See L<Elastic::Model::TypeMap::Base> for instructions on how to define
your own type-maps

