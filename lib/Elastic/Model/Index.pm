package Elastic::Model::Index;

use Carp;
use Moose;
with 'Elastic::Model::Role::Index';

use namespace::autoclean;

no Moose;

#===================================
sub create {
#===================================
    my $self   = shift;
    my $params = $self->index_config(@_);

    $self->es->create_index($params);
    return $self;
}

1;

__END__

# ABSTRACT: Create and administer indices in ElasticSearch

=head1 SYNOPSIS

    $index = $model->namespace('myapp')->index;
    $index = $model->namespace('myapp')->index('index_name');

    $index->create( settings => \%settings );

See also L<Elastic::Model::Role::Index/SYNOPSIS>.

=head1 DESCRIPTION

L<Elastic::Model::Index> objects are used to create and administer indices
in an ElasticSearch cluster.

See L<Elastic::Model::Role::Index> for more about usage.
See L<Elastic::Manual::Scaling> for more about how indices can be used in your
application.

=head1 METHODS

=head2 create()

    $index = $index->create();
    $index = $index->create( settings => \%settings, types => \@types );

Creates an index called L<name|Elastic::Role::Model::Index/name> (which
defaults to C<< $namespace->name >>).

The L<type mapping|Elastic::Manual::Terminology/Mapping> is automatically
generated from the attributes of your doc classes listed in the
L<namespace|Elastic::Model::Namespace>.  Similarly, any
L<custom analyzers|Elastic::Model/"Custom analyzers"> required
by your classes are added to the index
L<\%settings|http://www.elasticsearch.org/guide/reference/api/admin-indices-update-settings.html>
that you pass in:

    $index->create( settings => {number_of_shards => 1} );

To create an index with a sub-set of the types known to the
L<namespace|Elastic::Model::Namespace>, pass in a list of C<@types>.

    $index->create( types => ['user','post' ]);

=head1 IMPORTED ATTRIBUTES

Attributes imported from L<Elastic::Model::Role::Index>

=head2 L<namespace|Elastic::Model::Role::Index/namespace>

=head2 L<name|Elastic::Model::Role::Index/name>

=head1 IMPORTED METHODS

Methods imported from L<Elastic::Model::Role::Index>

=head2 L<close()|Elastic::Model::Role::Index/close()>

=head2 L<open()|Elastic::Model::Role::Index/open()>

=head2 L<refresh()|Elastic::Model::Role::Index/refresh()>

=head2 L<delete()|Elastic::Model::Role::Index/delete()>

=head2 L<update_analyzers()|Elastic::Model::Role::Index/update_analyzers()>

=head2 L<update_settings()|Elastic::Model::Role::Index/update_settings()>

=head2 L<delete_mapping()|Elastic::Model::Role::Index/delete_mapping()>

=head2 L<is_alias()|Elastic::Model::Role::Index/is_alias()>

=head2 L<is_index()|Elastic::Model::Role::Index/is_index()>

=head1 SEE ALSO

=over

=item *

L<Elastic::Model::Role::Index>

=item *

L<Elastic::Model::Alias>

=item *

L<Elastic::Model::Namespace>

=item *

L<Elastic::Manual::Scaling>

=back
