package Elastic::Model::Results;

use Carp;
use Moose;
with 'Elastic::Model::Role::Results';
use MooseX::Types::Moose qw(:all);

use namespace::autoclean;

#===================================
has 'took' => (
#===================================
    isa    => Num,
    is     => 'ro',
    writer => '_set_took',
);

#===================================
has '+wrapper' => (
#===================================
    builder => 'as_results'
);

no Moose;

#===================================
sub BUILD {
#===================================
    my $self   = shift;
    my $result = $self->model->es->search( $self->search );

    croak "Search timed out" if $result->{timed_out};

    $self->_set_took( $result->{took} );
    $self->_set_total( $result->{hits}{total} );
    $self->_set_elements( $result->{hits}{hits} );
    $self->_set_facets( $result->{facets} || {} );
    $self->_set_max_score( $result->{max_score} || 0 );
}

1;

__END__

# ABSTRACT: An iterator over bounded/finite search results

=head1 SYNOPSIS

Twenty most recently updated active users:

    $users = $model->view
                   ->index('my_domain')
                   ->type('user')
                   ->filterb({ status => 'active' })
                   ->sort({ timestamp => 'desc'})
                   ->size(20)
                   ->search
                   ->as_objects;

    while (my $user = $users->next) {
        $user->do_something()
    }

Ten most relevant posts for keywords C<perl moose> created since the beginning
of 2012, with highlighted snippets, plus the most popular tags:

    $keywords = 'perl moose';
    $results  = $model  ->view
                        ->index('my_domain')
                        ->type('posts')
                        ->queryb({ content => $keywords })
                        ->filterb({ created => { gt => '2012-01-01' }})
                        ->highlight({ fields => { content => {}}})
                        ->facets({ tags => { terms => { field => 'tags' }}})
                        ->search;

    printf "Showing %d of %d matching docs\n", $results->size, $results->total;

    say "Popular tags: ";

    my $tags = $results->facets('tags');

    printf "%s (%d) \n", $_->{term}, $_->{count};
        for @{$tags->{terms}};

    printf "And %d more... \n", $tags->{other};

    while (my $result = $results->next) {
        say "Title:"      . $result->object->title;
        say "Highlights:" .join ', ', $result->highlight('content');
    }


=head1 DESCRIPTION

An L<Elastic::Model::Results> object is returned when you call
L<Elastic::Model::View/search()>, and is intended for searches that retrieve
a maximum of L<Elastic::Model::View/size> results in a single request.

By default, the short L<Elastic::Model::Role::Iterator/"WRAPPED ACCESSORS">
return L<Elastic::Model::Result> objects, but you can change this by
calling L<Elastic::Model::Role::Results/as_objects()>.

Most attributes and accessors in this class come from
L<Elastic::Model::Role::Results> and L<Elastic::Model::Role::Iterator>.

=head1 ATTRIBUTES

=head2 took

    $took = $results->took

The number of milliseconds that the request took to run.

=head2 search

    \%search_args = $results->search

See L<Elastic::Model::Role::Results/search>.

=head2 total

    $total_matching = $results->total

See L<Elastic::Model::Role::Results/total>.

=head2 max_score

    $max_score = $results->max_score

See L<Elastic::Model::Role::Results/max_score>.

=head2 facets

    $facets = $results->facets

See L<Elastic::Model::Role::Results/facets>.

=head1 ITERATOR CONTROL

=head2 index

    $index = $iter->index;      # index of the current element, or undef
    $iter->index(0);            # set the current element to the first element
    $iter->index(-1);           # set the current element to the last element
    $iter->index(undef);        # resets the iterator, no current element

See L<Elastic::Model::Role::Iterator/index>.

=head2 reset

    $iter->reset;

See L<Elastic::Model::Role::Iterator/reset>.

=head1 INFORMATIONAL ACCESSORS

=head2 size

    $size = $iter->size;

See L<Elastic::Model::Role::Iterator/size>.

=head2 even

    $bool = $iter->even

See L<Elastic::Model::Role::Iterator/even>.

=head2 odd

    $bool = $iter->odd

See L<Elastic::Model::Role::Iterator/odd>.

=head2 parity

    $parity = $iter->parity

See L<Elastic::Model::Role::Iterator/parity>.

=head2 is_first

    $bool = $iter->is_first

See L<Elastic::Model::Role::Iterator/is_first>.

=head2 is_last

    $bool = $iter->is_last

See L<Elastic::Model::Role::Iterator/is_last>.

=head2 has_next

    $bool = $iter->has_next

See L<Elastic::Model::Role::Iterator/has_next>.

=head2 has_prev

    $bool = $iter->has_prev

See L<Elastic::Model::Role::Iterator/has_prev>.

=head1 WRAPPERS

=head2 as_results()

    $results = $results->as_results;

See L<Elastic::Model::Role::Results/as_results()>. This is the default.

=head2 as_objects()

    $objects = $objects->as_objects;

See L<Elastic::Model::Role::Results/as_objects()>.


=head2 as_elements()

    $iter->as_elements()

See L<Elastic::Model::Role::Iterator/as_elements()>.

=head1 WRAPPED ACCESSORS

=head2 first

    $wrapped_el = $iter->first

See L<Elastic::Model::Role::Iterator/first>.

=head2 next

    $wrapped_el = $iter->next;

See L<Elastic::Model::Role::Iterator/next>.

=head2 prev

    $wrapped_el = $iter->prev;

See L<Elastic::Model::Role::Iterator/prev>.

=head2 current

    $wrapped_el = $iter->current;

See L<Elastic::Model::Role::Iterator/current>.

=head2 last

    $wrapped_el = $iter->last

See L<Elastic::Model::Role::Iterator/last>.

=head2 peek_next

    $wrapped_el = $iter->peek_next

See L<Elastic::Model::Role::Iterator/peek_next>.

=head2 peek_prev

    $wrapped_el = $iter->peek_prev

See L<Elastic::Model::Role::Iterator/peek_prev>.

=head2 pop

    $wrapped_el = $iter->pop

See L<Elastic::Model::Role::Iterator/pop>.

=head2 slice

    @wrapped_els = $iter->slice

See L<Elastic::Model::Role::Iterator/slice>.

=head2 all

    @wrapped_els = $iter->all

See L<Elastic::Model::Role::Iterator/all>.

=head1 RESULT ACCESSORS

=head2 first_result

    $result = $results->first_result

See L<Elastic::Model::Role::Results/first_result>.

=head2 last_result

    $result = $results->last_result

See L<Elastic::Model::Role::Results/last_result>.

=head2 next_result

    $result = $results->next_result

See L<Elastic::Model::Role::Results/next_result>.

=head2 prev_result

    $result = $results->prev_result

See L<Elastic::Model::Role::Results/prev_result>.

=head2 current_result

    $result = $results->current_result

See L<Elastic::Model::Role::Results/current_result>.

=head2 peek_next_result

    $result = $results->peek_next_result

See L<Elastic::Model::Role::Results/peek_next_result>.

=head2 peek_prev_result

    $result = $results->peek_prev_result

See L<Elastic::Model::Role::Results/peek_prev_result>.

=head2 pop_result

    $result = $results->pop_result

See L<Elastic::Model::Role::Results/pop_result>.

=head2 all_results

    @results = $results->all_results

See L<Elastic::Model::Role::Results/all_results>.

=head2 slice_results

    @results = $results->slice_results

See L<Elastic::Model::Role::Results/slice_results>.

=head1 OBJECT ACCESSORS

=head2 first_object

    $object = $objects->first_object

See L<Elastic::Model::Role::Results/first_object>.

=head2 last_object

    $object = $objects->last_object

See L<Elastic::Model::Role::Results/last_object>.

=head2 next_object

    $object = $objects->next_object

See L<Elastic::Model::Role::Results/next_object>.

=head2 prev_object

    $object = $objects->prev_object

See L<Elastic::Model::Role::Results/prev_object>.

=head2 current_object

    $object = $objects->current_object

See L<Elastic::Model::Role::Results/current_object>.

=head2 peek_next_object

    $object = $objects->peek_next_object

See L<Elastic::Model::Role::Results/peek_next_object>.

=head2 peek_prev_object

    $object = $objects->peek_prev_object

See L<Elastic::Model::Role::Results/peek_prev_object>.

=head2 pop_object

    $object = $objects->pop_object

See L<Elastic::Model::Role::Results/pop_object>.

=head2 all_objects

    @objects = $objects->all_objects

See L<Elastic::Model::Role::Results/all_objects>.

=head2 slice_objects

    @objects = $objects->slice_objects

See L<Elastic::Model::Role::Results/slice_objects>.


=head1 ELEMENT ACCESSORS

=head2 elements

    \@elements = $iter->elements;

See L<Elastic::Model::Role::Iterator/elements>.

=head2 first_element

    $el = $iter->first_element;

See L<Elastic::Model::Role::Iterator/first_element>.

=head2 next_element

    $el =  $iter->next_element;

See L<Elastic::Model::Role::Iterator/next_element>.

=head2 prev_element

    $el =  $iter->prev_element;

See L<Elastic::Model::Role::Iterator/prev_element>.

=head2 current_element

    $el =  $iter->current_element;

See L<Elastic::Model::Role::Iterator/current_element>.

=head2 last_element

    $el = $iter->last_element;

See L<Elastic::Model::Role::Iterator/last_element>.

=head2 peek_next_element

    $el = $iter->peek_next_element;

See L<Elastic::Model::Role::Iterator/peek_next_element>.

=head2 peek_prev_element

    $el = $iter->peek_prev_element;

See L<Elastic::Model::Role::Iterator/peek_prev_element>.

=head2 pop_element

    $el = $iter->pop_element

See L<Elastic::Model::Role::Iterator/pop_element>.

=head2 slice_elements

    @els = $iter->slice($offset,$length);

See L<Elastic::Model::Role::Iterator/slice_elements>.

=head2 all_elements

    @elements = $iter->all_elements

See L<Elastic::Model::Role::Iterator/all_elements>.

