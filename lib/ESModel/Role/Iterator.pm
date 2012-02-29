package ESModel::Role::Iterator;

use Carp;
use Moose::Role;
use MooseX::Types::Moose qw(:all);
use MooseX::Attribute::Chained;

has 'elements' => (
    isa     => ArrayRef,
    traits  => ['Array'],
    is      => 'ro',
    writer  => '_set_elements',
    handles => {
        'get_element'  => 'get',
        'all_elements' => 'elements',
    },
    default => sub { [] },
);

has 'page_size' => (
    isa     => Int,
    is      => 'rw',
    default => 10
);

has '_i' => (
    isa     => Int,
    is      => 'rw',
    default => -1,
);

has 'wrapper' => (
    traits  => ['Chained'],
    isa     => CodeRef,
    is      => 'rw',
    lazy    => 1,
    builder => 'as_elements',
);

after 'all_elements' => sub { shift->reset };

no Moose;

#===================================
sub _incr_i {
#===================================
    my $self = shift;
    my $i    = $self->_i + 1;
    $self->_i( $i >= $self->size ? -1 : $i );
}

#===================================
sub _decr_i {
#===================================
    my $self = shift;
    my $i    = $self->_i - 1;
    $self->_i( $i < 0 ? -1 : 0 );
}

#===================================
sub size { 0 + @{ shift->elements } }
#===================================

#===================================
sub index {
#===================================
    my $self = shift;
    if (@_) {
        my $index = my $original = shift;
        if ( defined $index ) {
            my $size = $self->size
                or
                $self->error("Index [$original] out of bounds. No values.");
            $index += $size
                if $index < 0;
            $self->error( "Index [$original] out of bounds. "
                    . "Values can be 0.."
                    . ( $size - 1 ) )
                if $index >= $size || $index < 0;
        }
        else { $index = -1 }
        $self->_i($index);
    }
    return $self->_i < 0 ? undef : $self->_i;
}

#===================================
sub reset { shift->_i(-1) }
#===================================

#===================================
sub first     { $_[0]->wrapper->( $_[0]->first_element ) }
sub last      { $_[0]->wrapper->( $_[0]->last_element ) }
sub next      { $_[0]->wrapper->( $_[0]->next_element ) }
sub prev      { $_[0]->wrapper->( $_[0]->prev_element ) }
sub current   { $_[0]->wrapper->( $_[0]->current_element ) }
sub peek_next { $_[0]->wrapper->( $_[0]->peek_next_element ) }
sub peek_prev { $_[0]->wrapper->( $_[0]->peek_prev_element ) }
sub pop       { $_[0]->wrapper->( $_[0]->pop_element ) }
sub all       { $_[0]->wrapper->( $_[0]->all_elements ) }
sub slice     { $_[0]->wrapper->( $_[0]->slice_elements ) }
#===================================

#===================================
sub first_element {
#===================================
    my $self = shift;
    $self->_i(0);
    $self->get_element(0);
}

#===================================
sub last_element {
#===================================
    my $self = shift;
    my $i    = $self->_i( $self->size - 1 );
    $self->get_element($i);
}

#===================================
sub current_element {
#===================================
    my $self = shift;
    return $self->get_element( $self->_i );
}

#===================================
sub next_element {
#===================================
    my $self = shift;
    my $i    = $self->_incr_i;
    return undef if $i < 0;
    return $self->get_element($i);
}

#===================================
sub prev_element {
#===================================
    my $self = shift;
    my $i    = $self->_decr_i;
    return undef if $i < 0;
    return $self->get_element($i);
}

#===================================
sub peek_next_element {
#===================================
    my $self = shift;
    my $i    = $self->_i;
    my $raw  = $self->next_element;
    $self->_i($i);
    return $raw;
}

#===================================
sub peek_prev_element {
#===================================
    my $self = shift;
    my $i    = $self->_i;
    my $raw  = $self->prev_element;
    $self->_i($i);
    return $raw;
}

#===================================
sub pop_element {
#===================================
    my $self = shift;
    $self->_i(-1);
    CORE::pop @{ $self->elements };
}

#===================================
sub even     { shift->_i % 2 }
sub odd      { !shift->even }
sub parity   { shift->even ? 'even' : 'odd' }
sub is_first { shift->_i == 0 }
sub is_last  { $_[0]->_i == $_[0]->size - 1 }
sub has_next { $_[0]->i < $_[0]->size - 1 }
sub has_prev { $_[0]->i > 0 }
#===================================

#===================================
sub slice_elements {
#===================================
    my $self   = shift;
    my $first  = shift || 0;
    my $offset = shift || 0;
    my $size   = $self->size;
    $first = $first + $size if $first < 0;
    my $last = $offset ? $first + $offset - 1 : $size - 1;
    if ( $last > $size - 1 ) {
        $last = $size - 1;
    }
    my @slice;
    if ( $first < $size && $first <= $last ) {
        my $elements = $self->elements;
        @slice = @{$elements}[ $first .. $last ];
    }
    return wantarray ? @slice : \@slice;
}

# TODO: extra methods for iterator
#=element C<page()>
#
#    %results = $browse->page($page_no)
#    %results = $browse->page(page => $page_no, page_size => $rows_per_page)
#
#Returns a HASH ref with the following keys:
#
# - total:       total number of elements in the list
# - page:        current page (will be the last available page if $page_no
#                greated than last_page
# - last_page:   the last available page
# - start_row:   the number of the first element (1..$total)
# - last_row:    the number of the last element
# - results:     an iterator containing the requested elements
#
#=cut
#
##===================================
#sub page {
##===================================
#    my $self = shift;
#    my %params
#        = @_ != 1 ? @_
#        : ref $_[0] eq ' HASH ' ? %{ $_[0] }
#        :                       ( page => $_[0] || 1 );
#
#    my $total = $self->size
#        or return;
#
#    my $page_size = $params{page_size} || 10;
#    my $last_page = int( ( $total - 1 ) / $page_size ) + 1;
#    my $page = make_int( $params{page} );
#
#    $page = 1          if $page < 1;
#    $page = $last_page if $page > $last_page;
#
#    my $start_index = ( $page - 1 ) * $page_size;
#    my %search      = (
#        page      => $page,
#        last_page => $last_page,
#        total     => $total,
#        start_row => $start_index + 1,
#        end_row   => $start_index + $page_size,
#        page_size => $page_size
#    );
#
#    $search{end_row} = $total if $total < $search{end_row};
#    $self->_index($start_index);
#
#    # so next_id gives us the first in the list
#    $self->prev_id;
#
#    my @ids;
#    for ( 1 .. $page_size ) {
#        my $id = $self->next_id || last;
#        push @ids, $id;
#    }
#
#    $search{results} = $self->_iterator_class->new(
#        class => $self->object_class,
#        ids   => \@ids
#    );
#
#    $search{results}->preload;
#    return \%search;
#}
#

#===================================
sub as_elements {
#===================================
    shift->wrapper( sub {@_} );
}

1;
