package ESModel::Role::Store;

use Moose::Role;
with 'ESModel::Role::ModelAttr';

use namespace::autoclean;
use ESModel::Types qw(ES);

has 'es' => (
    isa      => ES,
    is       => 'ro',
    builder  => '_build_es',
    lazy => 1,
);

#===================================
sub _build_es { shift->model->es }
#===================================

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

1;
