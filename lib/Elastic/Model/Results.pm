package Elastic::Model::Results;

use Carp;
use Moose;
with 'Elastic::Model::Role::Results';
use MooseX::Types::Moose qw(:all);

use namespace::autoclean;

has 'took' => (
    isa    => Num,
    is     => 'ro',
    writer => '_set_took',
);

has '+wrapper' => ( builder => '_as_result' );

no Moose;

#===================================
sub BUILD {
#===================================
    my $self   = shift;
    my $result = $self->model->es->search( $self->search );

    # TODO: handle partial results if some shards failed?
    croak "Search timed out" if $result->{timed_out};

    $self->_set_took( $result->{took} );
    $self->_set_total( $result->{hits}{total} );
    $self->_set_elements( $result->{hits}{hits} );
    $self->_set_facets( $result->{facets} || {} );
    $self->_set_max_score( $result->{max_score} || 0 );
}

1;
