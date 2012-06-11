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


=head1 CONSUMES

L<Elastic::Model::Role::Index>

=head1 DESCRIPTION

L<Elastic::Model::Index> objects are used to create and administer indices
in an ElasticSearch cluster.

=head1 METHODS

=head2 create()

    $index = $index->create();
    $index = $index->create( settings => %settings, types => \@types );

Creates an index called L<name|Elastic::Role::Model::Index/name> (which
defaults to C<< $namespace->name >>).

The L<type mapping|Elastic::Manual::Terminology/Mapping> is automatically
generated from the attributes of your doc classes listed in the
L<namespace|Elastic::Model::Namespace>.  Similarly, any
L<custom analyzers|Elastic::Model/"Custom analyzers"> required
by your classes are added to the index
L<%settings|http://www.elasticsearch.org/guide/reference/api/admin-indices-update-settings.html>
that you pass in:

    $index->create( settings => {number_of_shards => 1} );

To create an index with a sub-set of the types known to the
L<namespace|Elastic::Model::Namespace>, pass in a list of C<@types>.

=head1 IMPORTED ATTRIBUTES

=head2 namespace

See L<Elastic::Model::Role::Index/namespace>

=head2 name

See L<Elastic::Model::Role::Index/name>

=head1 IMPORTED METHODS

=head2 close()

See L<Elastic::Model::Role::Index/close()>

=head2 open()

See L<Elastic::Model::Role::Index/open()>

=head2 refresh()

See L<Elastic::Model::Role::Index/refresh()>

=head2 delete()

See L<Elastic::Model::Role::Index/delete()>

=head2 update_analyzers()

See L<Elastic::Model::Role::Index/update_analyzers()>

=head2 update_settings()

See L<Elastic::Model::Role::Index/update_settings()>

=head2 delete_mapping()

See L<Elastic::Model::Role::Index/delete_mapping()>

=head2  is_alias()

See L<Elastic::Model::Role::Index/is_alias()>

=head2 is_index()

See L<Elastic::Model::Role::Index/is_index()>

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
