package ESModel::Results::Scrolled;

use Carp;
use Moose;
with 'ESModel::Role::Results';
use MooseX::Types::Moose qw(:all);

has '_scroll' => (
    isa    => 'ElasticSearch::ScrolledSearch',
    is     => 'ro',
    writer => '_set_scroll',
);

has '_virtual_size' => (
    isa    => Int,
    is     => 'ro',
    writer => '_set_virtual_size',
);

#===================================
sub BUILD {
#===================================
    my $self   = shift;
    my $scroll = $self->model->store->scrolled_search( $self->search );
    $self->_set_scroll($scroll);

    # handle partial results if some shards failed?
    #    croak "Search timed out" if $result->{timed_out};

    $self->_set_total( $scroll->total );
    $self->_set_virtual_size( $scroll->total );
    $self->_set_facets( $scroll->facets || {} );
    $self->_set_max_score( $scroll->max_score || 0 );
}

#===================================
sub size { shift->_virtual_size }
#===================================

#===================================
before '_i' => sub {
#===================================
    my $self = shift;
    if (@_) {
        my $i = shift;
        $self->_fetch_until($i) if $i > -1;
    }
};

#===================================
before 'pop_element' => sub {
#===================================
    my $self = shift;
    $self->_fetch_until(0);
    my $size = $self->size;
    $self->_set_virtual_size( $size > 0 ? $size - 1 : 0 );
};

#===================================
sub _fetch_until {
#===================================
    my $self     = shift;
    my $i        = shift || 0;
    my $scroll   = $self->_scroll;
    my $elements = $self->elements;
    while ( !$scroll->eof && $i >= @{$elements} ) {
        push @{$elements}, $scroll->drain_buffer;    ### pass max?
    }
}

1;
