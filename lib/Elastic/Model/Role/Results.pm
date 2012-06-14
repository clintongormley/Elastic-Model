package Elastic::Model::Role::Results;

use Carp;
use Moose::Role;

with 'Elastic::Model::Role::Iterator';

use MooseX::Types::Moose qw(:all);
use namespace::autoclean;

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

has '_as_results' => (
    isa     => CodeRef,
    is      => 'ro',
    lazy    => 1,
    builder => '_as_results_builder'
);

has '_as_object' => (
    isa     => CodeRef,
    is      => 'ro',
    lazy    => 1,
    builder => '_as_object_builder'
);

has '_as_objects' => (
    isa     => CodeRef,
    is      => 'ro',
    lazy    => 1,
    builder => '_as_objects_builder'
);

no Moose;

#===================================
sub _as_result_builder {
#===================================
    my $self         = shift;
    my $result_class = $self->model->result_class;
    sub { $_[0] && $result_class->new( result => $_[0] ) }
}

#===================================
sub _as_results_builder {
#===================================
    my $self         = shift;
    my $result_class = $self->model->result_class;
    sub {
        map { $result_class->new( result => $_ ) } @_;
    };
}

#===================================
sub _as_object_builder {
#===================================
    my $self  = shift;
    my $model = $self->model;
    sub {
        my $raw = shift or return;
        my $uid = Elastic::Model::UID->new_from_store($raw);
        $model->get_doc( uid => $uid, source => $raw->{_source} );
    };
}

#===================================
sub _as_objects_builder {
#===================================
    my $self = shift;
    my $m    = $self->model;
    sub {
        map {
            my $uid = Elastic::Model::UID->new_from_store($_);
            $m->get_doc( uid => $uid, source => $_->{_source} )
        } @_;
    };
}

#===================================
sub as_results {
#===================================
    my $self = shift;
    $self->wrapper( $self->_as_result );
    $self->multi_wrapper( $self->_as_results );
}

#===================================
sub as_objects {
#===================================
    my $self = shift;
    $self->wrapper( $self->_as_object );
    $self->multi_wrapper( $self->_as_objects );
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
sub all_results      { $_[0]->_as_results->( $_[0]->all_elements ) }
sub slice_results    { $_[0]->_as_results->( $_[0]->slice_elements ) }
#===================================

#===================================
sub first_object     { $_[0]->_as_object->( $_[0]->first_element ) }
sub last_object      { $_[0]->_as_object->( $_[0]->last_element ) }
sub next_object      { $_[0]->_as_object->( $_[0]->next_element ) }
sub prev_object      { $_[0]->_as_object->( $_[0]->prev_element ) }
sub current_object   { $_[0]->_as_object->( $_[0]->current_element ) }
sub peek_next_object { $_[0]->_as_object->( $_[0]->peek_next_element ) }
sub peek_prev_object { $_[0]->_as_object->( $_[0]->peek_prev_element ) }
sub pop_object       { $_[0]->_as_object->( $_[0]->pop_element ) }
sub all_objects      { $_[0]->_as_objects->( $_[0]->all_elements ) }
sub slice_objects    { $_[0]->_as_objects->( $_[0]->slice_elements ) }
#===================================

1;

__END__

# ABSTRACT: An iterator role for search results

=head1 DESCRIPTION

L<Elastic::Model::Role::Results> adds a number of methods and attributes
to those provided by L<Elastic::Model::Role::Iterator> to better handle
result sets from ElasticSearch.  It is used by L<Elastic::Model::Results>
and by L<Elastic::Model::Results::Scrolled>.

Depending on your requirements, you may prefer to iterate through your
results as L<Elastic::Model::Result> objects (which includes all data returned
for each result, eg highlighted snippets) or as just the doc objects themselves.

For instance, if you wanted to show search results to a user, you could use
L</as_results()> to do:

    $results = $view->type('post')
                    ->queryb({ content => 'perl moose' })
                    ->highlight({ fields => { content => {} }})
                    ->search
                    ->as_results;

    print "Showing ".$results->size." of ".$results->total;

    while (my $result = $results->next) {
        print "Post title: " . $result->object->title;
        print "Highlights:"  . join ', ', $result->highlight('short_text');
    }

But if you wanted to iterate through all user objects with C<status == pending>,
you could use L</as_objects()> to do:

    $users  =  $view->type('user')
                    ->filterb( status => 'pending' )
                    ->scan
                    ->as_objects;

    while (my $user = $users->next) {
        $user->status('approved');
        $user->save;
    }


=head1 ATTRIBUTES

=head2 search

    \%search_args = $results->search

Contains the hash ref of the search request passed to
L<Elastic::Model::Role::Store/search()>

=head2 total

    $total_matching = $results->total

The total number of matching docs found by ElasticSearch.  This is
distinct from the L<Elastic::Model::Role::Iterator/"size"> which
contains the number of results RETURNED by ElasticSearch.

=head2 max_score

    $max_score = $results->max_score

The highest score (relevance) found by ElasticSearch. B<Note:> if you
are sorting by a field other than C<_score> then you will need
to set L<Elastic::Model::View/track_scores> to true to retrieve the
L</max_score>.

=head2 facets

    $facets = $results->facets

The facet results, if any were requested with L<Elastic::Model::View/facets>.

=head1 RESULT ACCESSORS

=head2 as_results()

    $results = $results->as_results;

L</as_results()> sets the L<Elastic::Model::Role::Iterator/"WRAPPED ACCESSORS">
to return L<Elastic::Model::Result> objects, with all the extra result
metadata.

Regardless of what the current L<Elastic::Model::Role::Iterator/wrapper>
is set to, you can retrieve L<Elastic::Model::Result> objects with
the following methods:

=head2 first_result

    $result = $results->first_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"first_element">.

=head2 last_result

    $result = $results->last_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"last_element">.

=head2 next_result

    $result = $results->next_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"next_element">.

=head2 prev_result

    $result = $results->prev_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"prev_element">.

=head2 current_result

    $result = $results->current_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"current_element">.

=head2 peek_next_result

    $result = $results->peek_next_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"peek_next_element">.

=head2 peek_prev_result

    $result = $results->peek_prev_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"peek_prev_element">.

=head2 pop_result

    $result = $results->pop_result

Creates a L<Elastic::Model::Result> object from the return value of
L<Elastic::model::Role::Iterator/"pop_element">.

=head2 all_results

    @results = $results->all_results

Creates L<Elastic::Model::Result> objects from the return value of
L<Elastic::model::Role::Iterator/"all_elements">.

=head2 slice_results

    @results = $results->slice_results

Creates L<Elastic::Model::Result> objects from the return value of
L<Elastic::model::Role::Iterator/"slice_elements">.


=head1 OBJECT ACCESSORS

=head2 as_objects()

    $objects = $objects->as_objects;

L</as_objects()> sets the L<Elastic::Model::Role::Iterator/"WRAPPED ACCESSORS">
to return just the doc object (eg C<MyApp::User> without all the result
metadata.

Regardless of what the current L<Elastic::Model::Role::Iterator/wrapper>
is set to, you can retrieve just doc objects with the following methods:

=head2 first_object

    $object = $objects->first_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"first_element">.

=head2 last_object

    $object = $objects->last_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"last_element">.

=head2 next_object

    $object = $objects->next_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"next_element">.

=head2 prev_object

    $object = $objects->prev_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"prev_element">.

=head2 current_object

    $object = $objects->current_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"current_element">.

=head2 peek_next_object

    $object = $objects->peek_next_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"peek_next_element">.

=head2 peek_prev_object

    $object = $objects->peek_prev_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"peek_prev_element">.

=head2 pop_object

    $object = $objects->pop_object

Inflates a doc object from the return value of
L<Elastic::model::Role::Iterator/"pop_element">.

=head2 all_objects

    @objects = $objects->all_objects

Inflates doc objects from the return value of
L<Elastic::model::Role::Iterator/"all_elements">.

=head2 slice_objects

    @objects = $objects->slice_objects

Inflates doc objects from the return value of
L<Elastic::model::Role::Iterator/"slice_elements">.


