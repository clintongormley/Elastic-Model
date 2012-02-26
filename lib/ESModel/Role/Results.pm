package ESModel::Role::Results;

use Carp;
use Moose::Role;

with 'ESModel::Role::Iterator';
with 'ESModel::Trait::Model';

use MooseX::Types::Moose qw(:all);
use ESModel::Doc::Result();

has 'search' => (
    isa      => HashRef,
    is       => 'ro',
    required => 1,
);

has 'total' => (
    isa    => Int,
    is     => 'ro',
    writer => '_set_total',
);

has 'max_score' => (
    isa    => Num,
    is     => 'ro',
    writer => '_set_max_score',
);

has 'facets' => (
    isa    => HashRef,
    is     => 'ro',
    writer => '_set_facets',
);

has '_as_result' => (
    isa     => CodeRef,
    is      => 'ro',
    lazy    => 1,
    builder => '_as_result_builder'
);

has '_as_object' => (
    isa     => CodeRef,
    is      => 'ro',
    lazy    => 1,
    builder => '_as_object_builder'
);

no Moose;

#===================================
sub _as_result_builder {
#===================================
    my $self  = shift;
    my $model = $self->model;
    sub {
        map { ESModel::Doc::Result->new( model => $model, result => $_ ) } @_;
    };
}

#===================================
sub _as_object_builder {
#===================================
    my $self  = shift;
    my $model = $self->model;
    sub { @_ > 1 ? $model->inflate_docs(@_) : $model->inflate_doc(@_) };
}

#===================================
sub as_results {
#===================================
    my $self = shift;
    $self->wrapper( $self->_as_result );
}

#===================================
sub as_objects {
#===================================
    my $self = shift;
    $self->wrapper( $self->_as_object );
}

#===================================
sub first_result     { $_[0]->_as_result->( $_[0]->first_element ) }
sub last_result      { $_[0]->_as_result->( $_[0]->last_element ) }
sub next_result      { $_[0]->_as_result->( $_[0]->next_element ) }
sub prev_result      { $_[0]->_as_result->( $_[0]->prev_element ) }
sub current_result   { $_[0]->_as_result->( $_[0]->current_element ) }
sub peek_next_result { $_[0]->_as_result->( $_[0]->peek_next_element ) }
sub peek_prev_result { $_[0]->_as_result->( $_[0]->peek_prev_element ) }
sub pop_result       { $_[0]->_as_result->( $_[0]->pop_element ) }
sub all_results      { $_[0]->_as_result->( $_[0]->all_elements ) }
sub slice_results    { $_[0]->_as_result->( $_[0]->slice_elements ) }
#===================================

#===================================
sub first_object     { $_[0]->_as_object->( $_[0]->first_element ) }
sub last_object      { $_[0]->_as_object->( $_[0]->last_element ) }
sub next_object      { $_[0]->_as_object->( $_[0]->next_element ) }
sub prev_object      { $_[0]->_as_object->( $_[0]->prev_element ) }
sub current_object   { $_[0]->_as_object->( $_[0]->current_element ) }
sub peek_next_object { $_[0]->_as_object->( $_[0]->peek_next_element ) }
sub peek_prev_object { $_[0]->_as_object->( $_[0]->peek_prev_element ) }
sub pop_object       { $_[0]->_as_result->( $_[0]->pop_object ) }
sub all_objects      { $_[0]->_as_object->( $_[0]->all_elements ) }
sub slice_objects    { $_[0]->_as_result->( $_[0]->slice_elements ) }
#===================================

1;
