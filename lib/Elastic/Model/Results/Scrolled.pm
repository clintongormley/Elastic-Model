package Elastic::Model::Results::Scrolled;

use Carp;
use Moose;
with 'Elastic::Model::Role::Results';
use MooseX::Types::Moose qw(:all);

use namespace::autoclean;

#===================================
has '_scroll' => (
#===================================
    isa    => 'ElasticSearch::ScrolledSearch',
    is     => 'ro',
    writer => '_set_scroll',
);

#===================================
has '_virtual_size' => (
#===================================
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

    # TODO: handle partial results if some shards failed?
    # TODO: croak "Search timed out" if $result->{timed_out};

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
before 'shift_element' => sub {
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
    while ( !$scroll->eof and $i > ( @$elements - 1 ) ) {
        push @$elements, $scroll->drain_buffer;
        $scroll->refill_buffer;
    }
}

#===================================
before 'all_elements' => sub {
#===================================
    my $self = shift;
    $self->_fetch_until( $self->size - 1 );
};

1;

__END__

# ABSTRACT: An iterator over unbounded search results

=head1 SYNOPSIS

=head1 DESCRIPTION

An L<Elastic::Model::Results::Scrolled> object is returned when you call
L<Elastic::Model::View/scroll()> or L<Elastic::Model::View/scan()>,
and is intended for searches that could potentially retrieve many results.
Results are retrieved from ElasticSearch in chunks.

By default, the short L<Elastic::Model::Role::Iterator/"WRAPPED ACCESSORS">
return results as doc objects (eg C<MyApp::User>), but you can change this
to receive L<Elastic::Model::Result> objects with all the search metadata
by calling L<Elastic::Model::Role::Results/as_results()>.

Most attributes and accessors in this class come from
L<Elastic::Model::Role::Results> and L<Elastic::Model::Role::Iterator>.

=head1

