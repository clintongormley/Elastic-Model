package Elastic::Model::Store;

use Moose;
with 'Elastic::Model::Role::Store';
use namespace::autoclean;

1;

__END__

# ABSTRACT: A default implementation of the Elasticsearch backend

=head1 DESCRIPTION

This is an empty class which provides the default implementation of
the Elasticsearch backend as implemented in L<Elastic::Model::Role::Store>.

=head1 IMPORTED ATTRIBUTES

=head2 L<es|Elastic::Model::Role::Store/es>

=head1 IMPORTED METHODS

=head2 L<get_doc()|Elastic::Model::Role::Store/get_doc()>

=head2 L<doc_exists()|Elastic::Model::Role::Store/doc_exists()>

=head2 L<create_doc()|Elastic::Model::Role::Store/create_doc()>

=head2 L<index_doc()|Elastic::Model::Role::Store/index_doc()>

=head2 L<delete_doc()|Elastic::Model::Role::Store/delete_doc()>

=head2 L<search()|Elastic::Model::Role::Store/search()>

=head2 L<scrolled_search()|Elastic::Model::Role::Store/scrolled_search()>
