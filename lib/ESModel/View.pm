package ESModel::View;

use Moose;

use Carp;
use ESModel::Types qw(IndexNames TypeNames SearchType);
use MooseX::Types::Moose qw(:all);
use MooseX::Attribute::ChainedClone();

use namespace::autoclean;

has 'index' => (
    traits  => ['ChainedClone'],
    isa     => IndexNames,
    is      => 'rw',
    lazy    => 1,
    builder => '_build_index_names',
    coerce  => 1,
);

has 'type' => (
    traits  => ['ChainedClone'],
    is      => 'rw',
    isa     => TypeNames,
    default => sub { [] },
    coerce  => 1,
);

has 'query' => (
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

has 'filter' => (
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

has 'post_filter' => (
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

has '_builder' => (
    isa     => Object,
    is      => 'ro',
    lazy    => 1,
    builder => '_build_builder'
);

has 'facets' => (
    traits => ['ChainedClone'],
    isa    => HashRef [HashRef],
    is     => 'rw'
);

has 'fields' => (
    traits  => ['ChainedClone'],
    isa     => ArrayRef [Str],
    is      => 'rw',
    default => sub { ['_source'] },
);

has 'from' => (
    traits  => ['ChainedClone'],
    isa     => Int,
    is      => 'rw',
    default => 0,
);
has 'size' => (
    traits  => ['ChainedClone'],
    isa     => Int,
    is      => 'rw',
    default => 10,
);

has 'sort' => (
    traits => ['ChainedClone'],
    isa    => ArrayRef,
    is     => 'rw',
);

has 'highlight' => (
    traits => ['ChainedClone'],
    isa    => ArrayRef [HashRef],
    is     => 'rw',
);

has 'indices_boost' => (
    traits => ['ChainedClone'],
    isa    => HashRef [Num],
    is     => 'rw',
);

has 'min_score' => (
    traits => ['ChainedClone'],
    isa    => Num,
    is     => 'rw',
);

has 'preference' => (
    traits => ['ChainedClone'],
    isa    => Str,
    is     => 'rw',
);

has 'routing' => (
    traits => ['ChainedClone'],
    isa    => Str,
    is     => 'rw',
);

has 'script_fields' => (
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

has 'timeout' => (
    traits => ['ChainedClone'],
    isa    => Str,
    is     => 'rw',
);

has 'track_scores' => (
    traits => ['ChainedClone'],
    isa    => Bool,
    is     => 'rw',
);

has 'search_builder' => (
    traits  => ['ChainedClone'],
    isa     => Object,
    is      => 'rw',
    lazy    => 1,
    builder => '_build_search_builder',
);

#===================================
sub _build_search_builder { shift->model->es->builder }
#===================================

#===================================
sub queryb {
#===================================
    my $self = shift;
    $self->query( $self->search_builder->query(@_)->{query} );
}

#===================================
sub filterb {
#===================================
    my $self = shift;
    $self->filter( $self->search_builder->filter(@_)->{filter} );
}

#===================================
sub post_filterb {
#===================================
    my $self = shift;
    $self->post_filter( $self->search_builder->filter(@_)->{filter} );
}

no Moose;

#===================================
sub _build_index_names { [ shift->model->meta->all_indices ] }
#===================================

#===================================
sub _single {
#===================================
    my ( $self,  $name )   = @_;
    my ( $first, $second ) = @{ $self->$name };
    if ( defined $second ) {
        my ($method) = ( caller(1) )[3];
        $method =~ s/.+:://;
        croak "$method() can only be called on a View with a single $name";
    }
    return $first;
}

#===================================
sub new_doc {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    $params{$_} ||= $self->_single($_) for qw(index type);
    $self->model->new_doc( \%params );
}

#===================================
sub create { shift->new_doc(@_)->save }
#===================================

#===================================
sub get {
#===================================
    my $self = shift;
    my %params
        = @_ != 1 ? @_
        : !ref $_[0]                 ? ( id  => shift() )
        : $_[0]->isa('ESModel::UID') ? ( uid => shift() )
        :                              %{ shift() };

    unless ( $params{uid} ) {
        $params{id} or croak "No 'id' passed to get()";
        $params{$_} ||= $self->_single($_) for qw(index type);
    }
    $self->model->get_doc(%params);
}

#===================================
sub search {
#===================================
    my $self = shift;
    $self->model->results_class->new( search => $self->_build_search );
}

# TODO: scroll_objects / scroll_results ?
#===================================
sub scroll {
#===================================
    my $self = shift;
    my $search = $self->_build_search( scroll => shift() || '1m', @_ );
    return $self->model->scrolled_results_class->new( search => $search, );
}

# TODO: scan_objects / scan_results
#===================================
sub scan {
#===================================
    my $self = shift;
    croak "A scan cannot be combined with sorting"
        if @{ $self->sort || [] };
    return $self->scroll( shift, search_type => 'scan' );
}

#===================================
sub delete {
#===================================
    my $self = shift;
    my %args = (
        ( map { $_ => $self->$_ } qw(index type routing ) ),
        query => $self->_build_query,
        @_
    );
    $self->store->delete_by_query( \%args );
}

# TODO: first_object / first_result
#===================================
sub first { shift->search(@_)->first }
sub total { shift->size(0)->search(@_)->total }

# TODO: sub facets { shift->size(0)->search(@_)->facets }
# TODO: sub page { shift->search->page(@_) }
#===================================

#===================================
sub _build_search {
#===================================
    my $self = shift;

    my %args = ( (
            map { $_ => $self->$_ }
                qw(
                index type sort from size highlight facets
                indices_boost min_score preference routing
                script_fields timeout track_scores
                )
        ),
        filter => $self->post_filter,
        query  => $self->_build_query,
        @_,
        version => 1,
        fields  => [ '_parent', '_routing', @{ $self->fields } ],

    );

    return { map { $_ => $args{$_} } grep { defined $args{$_} } keys %args };
}

#===================================
sub _build_query {
#===================================
    my $self = shift;
    my $q    = $self->query;
    my $f    = $self->filter;
    return { match_all => {} } unless $q or $f;

    return
         !$q ? { constant_score => { filter => $f } }
        : $f ? { filtered_query => { query => $q, filter => $f } }
        :      $q;
}

# TODO: extra methods for View
#    count
#    delete
#    delete( { %qs } )
#    get
#    get( { %qs } )
#    put
#    put( { %qs } )
#    new_document
#    raw
#
#
#
#    query/queryb
#    filter/filterb
#
#    facets
#    fields          ## partial object?
#    from
#    highlight
#    indices_boost
#    min_score
#    preference
#    routing
#    script_fields
#    search_type
#
#
#
#
#
#    size
#    sort
#    scroll
#    track_scores
#    timeout
#    version

#    search
#    find ?
#    search_related ?
#    cursor (scroll?)
#    single?
#    slice
#    next
#    count
#    all
#    reset
#    first
#    update?
#    update_all?
#    delete
#    delete_all
#    populate/bulk create?
#    pager?
#    page
#
#    find_or_new
#    create
#    find_or_create
#

1;
