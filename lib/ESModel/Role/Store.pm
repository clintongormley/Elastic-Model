package ESModel::Role::Store;

use Moose::Role;
with 'ESModel::Trait::Model';

use namespace::autoclean;
use ESModel::Types qw(ES);

has 'es' => (
    isa      => ES,
    is       => 'ro',
    required => 1,
);

#===================================
sub search          { shift->es->search(@_) }
sub scrolled_search { shift->es->scrolled_search(@_) }
#===================================

#===================================
sub get_doc {
#===================================
    my ( $self, $metadata ) = @_;

    return $self->es->get(
        fields => [qw(_routing _parent _source)],
        $metadata->uid_params
    );
}

#===================================
sub create_doc { shift->_write_doc( 'create', @_ ) }
sub index_doc  { shift->_write_doc( 'index',  @_ ) }
#===================================

#===================================
sub _write_doc {
#===================================
    my ( $self, $action, $metadata, $data, $args ) = @_;
    return $self->es->$action(
        data => $data,
        $metadata->uid_version_params,
        %$args
    );
}

#===================================
sub delete_doc {
#===================================
    my ( $self, $metadata, $args ) = @_;
    return $self->es->delete( $metadata->uid_version_params, %$args );
}

# - get_doc
# - get_docs
# - create_doc
# - create_docs
# - index_doc
# - index_docs
# - search
# - scrolled_search
# inflate_doc?

1;
