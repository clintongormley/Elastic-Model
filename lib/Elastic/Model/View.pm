package Elastic::Model::View;

use Moose;

use Carp;
use Elastic::Model::Types qw(IndexNames TypeNames SearchType SortArgs);
use MooseX::Types::Moose qw(:all);
use MooseX::Attribute::ChainedClone();

use namespace::autoclean;

#===================================
has 'domain' => (
#===================================
    traits  => ['ChainedClone'],
    isa     => IndexNames,
    is      => 'rw',
    lazy    => 1,
    builder => '_build_index_names',
    coerce  => 1,
);

#===================================
has 'type' => (
#===================================
    traits  => ['ChainedClone'],
    is      => 'rw',
    isa     => TypeNames,
    default => sub { [] },
    coerce  => 1,
);

#===================================
has 'query' => (
#===================================
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

#===================================
has 'filter' => (
#===================================
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

#===================================
has 'post_filter' => (
#===================================
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

#===================================
has '_builder' => (
#===================================
    isa     => Object,
    is      => 'ro',
    lazy    => 1,
    builder => '_build_builder'
);

#===================================
has 'facets' => (
#===================================
    traits => ['ChainedClone'],
    isa    => HashRef [HashRef],
    is     => 'rw'
);

#===================================
has 'fields' => (
#===================================
    traits  => ['ChainedClone'],
    isa     => ArrayRef [Str],
    is      => 'rw',
    default => sub { ['_source'] },
);

#===================================
has 'from' => (
#===================================
    traits  => ['ChainedClone'],
    isa     => Int,
    is      => 'rw',
    default => 0,
);

#===================================
has 'size' => (
#===================================
    traits  => ['ChainedClone'],
    isa     => Int,
    is      => 'rw',
    default => 10,
);

#===================================
has 'sort' => (
#===================================
    traits => ['ChainedClone'],
    isa    => SortArgs,
    is     => 'rw',
    coerce => 1,
);

#===================================
has 'highlight' => (
#===================================
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

#===================================
has 'index_boost' => (
#===================================
    traits => ['ChainedClone'],
    isa    => HashRef [Num],
    is     => 'rw',
);

#===================================
has 'min_score' => (
#===================================
    traits => ['ChainedClone'],
    isa    => Num,
    is     => 'rw',
);

#===================================
has 'preference' => (
#===================================
    traits => ['ChainedClone'],
    isa    => Str,
    is     => 'rw',
);

#===================================
has 'routing' => (
#===================================
    traits => ['ChainedClone'],
    isa    => ArrayRef[Str],
    is     => 'rw',
);

#===================================
has 'script_fields' => (
#===================================
    traits => ['ChainedClone'],
    isa    => HashRef,
    is     => 'rw',
);

#===================================
has 'timeout' => (
#===================================
    traits => ['ChainedClone'],
    isa    => Str,
    is     => 'rw',
);

#===================================
has 'track_scores' => (
#===================================
    traits => ['ChainedClone'],
    isa    => Bool,
    is     => 'rw',
);

#===================================
has 'search_builder' => (
#===================================
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
sub _build_index_names { [ Class::MOP::class_of(shift->model)->all_domains ] }
#===================================

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
        index => $self->domain,
        ( map { $_ => $self->$_ } qw(type routing ) ),
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
                type sort from size highlight facets
                index_boost min_score preference routing
                script_fields timeout track_scores
                )
        ),
        index => $self->domain,
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

__END__

# ABSTRACT: Views to query your docs in ElasticSearch

=head1 SYNOPSIS

    $view  = $model->view->domain('my_domain');
    $posts = $view->type('post');

10 most relevant posts containing C<'perl'> or C<'moose'>

    $results = $posts->queryb({ content => 'perl moose' });

10 most relevant posts containing C<'perl'> or C<'moose'> published in 2012,
sorted by C<timestamp>, with highlighted snippets from the C<content> field

    $results = $posts
                ->queryb({ content => 'perl moose' })
                ->filterb({
                    created => {
                        gte => '2012-01-01',
                        lt  => '2013-01-01'
                   }})
                ->sort({ timestamp => 'asc' })
                ->highlight({ field => { content => {} }});

Efficiently retrieve all posts, unsorted:

    $results = $posts->size(100)->scan('2m');
    while (my $result = $results->pop_result)) {
        # do something
    );

=head1 DESCRIPTION

L<Elastic::Model::View> is used to query your data.  Views are "chainable",
in other words, you create a new view every time you set another option.

For instance, you could do:

    $all_types      = $domain->view;
    $users          = $all_types->users;
    $posts          = $all_types->posts;
    $recent_posts   = $posts->filter({ published => { gt => '2012-05-01' }});

To retrieve the results, you can use one of the "finalisers", eg:

    $results        = $recent_posts->search;    # retrieve $size results
    $scroll         = $recent_posts->scroll;    # keep pulling results

=head1 ATTRIBUTES

=head2 domain

    $new_view = $view->domain('my_index');
    $new_view = $view->domain(['index_one','alias_two']);

By default, a C<view> will query all the domains known to a
L<model|Elastic::Model::Role::Model>.  You can specify one or more domains.

=head2 type

    $new_view = $view->type('user');
    $new_view = $view->type(['user','post']);

By default, a C<view> will query all types in all L<domains/"domain"> specified
in the view.  You can specify one or more types.

=head2 query

    $new_view = $view->query({ text => { title => 'interesting words' }});

By default, a view will run a L<match_all|http://www.elasticsearch.org/guide/reference/query-dsl/match-all-query.html>
query.  You can specify a query in the raw
L<ElasticSearch query DSL|http://www.elasticsearch.org/guide/reference/query-dsl/>.

=head2 queryb

    $new_view = $view->queryb({ title => 'interesting words' })

Instead of the raw ElasticSearch query DSL, you can use the more Perlish
L<ElasticSearch::SearchBuilder> query syntax.  This will translate the
query to the raw DSL and set L</query>.

=head2 filter

    $new_view = $view->filter({ term => { tag => 'perl' }});

You can filter the query results in the raw ElasticSearch query DSL.
If a filter is specified, it will be combined with the L</query>
as a L<filtered query|http://www.elasticsearch.org/guide/reference/query-dsl/filtered-query.html>.
or (if no query is specified) as a
L<constant score|http://www.elasticsearch.org/guide/reference/query-dsl/constant-score-query.html>
query.

=head2 filterb

    $new_view = $view->filter({ tag => 'perl' });

Instead of the raw ElasticSearch query DSL, you can use the more Perlish
L<ElasticSearch::SearchBuilder> query syntax.  This will translate the
filter to the raw DSL and set L</filter>.

=head2 post_filter

    $new_view = $view->post_filter({ term => { tag => 'perl' }});

L<Post-filters|http://www.elasticsearch.org/guide/reference/api/search/filter.html>
filter the results AFTER the L<facets> have been calculated.  In the above
example, the facets would be calculated on all values of C<tag>, but the
results would then be limited to just those docs where C<tag == perl>.
L</post_filter> accepts the raw ElasticSearch query DSL.

=head2 post_filterb

    $new_view = $view->post_filter({ tag => 'perl' });

Instead of the raw ElasticSearch query DSL, you can use the more Perlish
L<ElasticSearch::SearchBuilder> query syntax.  This will translate the
filter to the raw DSL and set L</post_filter>.

=head2 sort

    $new_view = $view->sort('_score');                # _score DESC
    $new_view = $view->sort('timestamp');             # timestamp ASC
    $new_view = $view->sort({timestamp => 'desc'});   # timestamp DESC

    $new_view = $view->sort([
        '_score',                                        # _score DESC
        { timestamp => 'desc' }                          # then timestamp ASC
    ]);

By default, results are sorted by "relevance" (C<< _score => 'desc' >>).
You can specify multiple sort arguments, which are applied in order.
See L<http://www.elasticsearch.org/guide/reference/api/search/sort.html> for
more information.

B<Note:> Sorting cannot be combined with L<scan()>.

=head2 from

    $new_view = $view->from(10);

By default, results are returned from the first result. If you would like to
start at a later result (eg for paging), you can set L</from>.

=head2 size

    $new_view = $view->size(100);

The number of results returned in a single L</search()>, which defaults to 10.

B<Note:> See L</scan()> for a slightly different interpretation of the L</size>
value.

=head2 facets

    $new_view = $view->facets()

# TODO: Should be add_facet

=head2 highlight

    $new_view = $view->highlight({
        pre_tags    => '<em>',
        post_tags   => '</em>',
        fields      => {
            title   => {},
            content => {}
        }
    });

Add L<highlighted snippets|http://www.elasticsearch.org/guide/reference/api/search/highlighting.html>
to your search results.

=head2 fields

    $new_view = $view->fields(['title','content']);

By default, searches will return the L<source|http://www.elasticsearch.org/guide/reference/mapping/source-field.html>
field which contains the whole document, allowing Elastic::Model to inflate
the original object without having to retrieve the document separately. If you
would like to just retrieve a subset of fields, you can specify them in
L</fields>. See L<http://www.elasticsearch.org/guide/reference/api/search/fields.html>.

=head2 script_fields

    $new_view = $view->script_fields({
        distance => {
            script  => q{doc['location'].distance(lat,lon)},
            params  => { lat => $lat, lon => $lon }
        }
    });

L<Script fields|http://www.elasticsearch.org/guide/reference/api/search/script-fields.html>
can be generated using the L<mvel|http://mvel.codehaus.org/Language+Guide+for+2.0>
scripting language. (You can also use L<Javascript, Python and Java|http://www.elasticsearch.org/guide/reference/modules/scripting>.)

=head2 routing

    $new_view = $view->routing('routing_val');
    $new_view = $view->routing(['routing_1','routing_2']);

Search queries are usually directed at all shards. If you are using routing
(eg to store related docs on the same shard) then you can limit the search
to just the relevant shard(s).

=head2 index_boost

    $new_view = $view->index_boost({ index_1 => 4, index_2 => 2 });

Make results from one index more relevant than those from another index.

## TODO: Does an alias name also work?

=head2 min_score

    $new_view = $view->min_score(2);

Exclude results whose score (relevance) is less than the specified number.

=head2 preference

    $new_view = $view->preference('_local');

Control which node should return search results. See
L<http://www.elasticsearch.org/guide/reference/api/search/preference.html> for more.

=head2 timeout

    $new_view = $view->timeout(10);         # 10 ms
    $new_view = $view->timeout('10s');      # 10 sec

Sets an upper limit on the the time to wait for search results, returning
with whatever results it has managed to receive up until that point.

=head2 track_scores

    $new_view = $view->track_scores(1);

By default, If you sort on a field other than C<_score>, ElasticSearch
does not return the calculated relevance score for each doc.  If
L</track_score> is true, these scores will be returned regardless.

=head2 search_builder

    $new_view = $view->search_builder($search_builder);

If you would like to use a different search builder than the default
L<ElasticSearch::SearchBuilder> for L</"queryb">, L</"filterb"> or
L</postfilterb>, then you can set a value for L</searchbuilder>.

=head1 METHODS

=head2 search()

    $results = $view->search();

Executes a search and returns a L<Elastic::Model::Results> object
with at most L</size> results.

This is useful for returning finite results, ie where you know how many
results you want.  For instance: "give me the best 10 results".

=head2 scroll()

    $timeout = '1m';
    $scrolled_results = $view->scroll($timeout);

Executes a search and returns a L<Elastic::Model::Results::Scrolled>
object which will pull L</size> results from ElasticSearch until either
(1) no more results are available or (2) more than C<$timeout> elapses
between requests to ElasticSearch.

Scrolling allows you to return an unbound result set.  Useful if you're not
sure whether to expect 2 results or 2000.  You can just keep pulling, and
it will give you more results until they run out.  The C<$scrolled_results>
object will pull a maximum of L</size> docs at a time, and maintain a buffer
internally. This makes it efficient to fetch a "reasonably" large number
of docs. (See L</scan()> for clarification of "reasonably").

Also, the results reflect the state of the index at the time at which the
initial query was made. If any docs have been updated in a way that would
give you different query results now, this won't affect your scrolled results.
This is useful for presenting consistent results to a user, so as to avoid
the same result appearing on page 1 and page 2.

The C<scroll> will be kept alive for a max time of C<$timeout> since the
last pull.  You don't want this number to be too high, as it will mean
that ElasticSearch has to keep many old indices live to serve them, or too
low, otherwise your scroll might disappear while you are pulling.  By default,
it is set to 1 minute.

=head2 scan()

    $timeout = '1m';
    $scrolled_results = $view->scan($timeout);

"Scan" is a special type of L</scroll()> request, intended for handling
large numbers of docs.

=head3 The problem with retrieving large numbers of docs

When you create an index in ElasticSearch, it is created (by default) with
5 primary shards. Each of your docs is stored in one of those shards. It is
these primary shards that allow you to scale your index size.

Let's consider what happens when you run a query like: "Give me the 10 most
relevant docs that match C<"foo bar">".

=over

=item *

Your query is sent to one of your ElasticSearch nodes.

=item *

That node forwards your query to all 5 shards in the index.

=item *

Each shard runs the query and finds the 10 most relevant docs, and returns
them to the requesting node.

=item *

The requesting node sorts these 50 docs by relevance, discards the 40 least
relevant, and returns the 10 most relevant.

=back

So then, if you ask for page 10,000 (ie results 100,001 - 100,010), each
shard has to return 100,010 docs, and the requesting node has to discard
500,040 of them!

That approach doesn't scale. More than likely the requesting node will just
run out of memory and be killed. There is a good reason why search engines
don't return more than 100 pages of results.

=head3 The solution: scanning

You can retrieve all docs in your index, as long as you don't need them
to be sorted, using scanning. Scanning works as follows:

=over

=item *

Your query is sent to one of your ElasticSearch nodes.

=item *

That node forwards your query to all 5 shards in the index.

=item *

Each shard runs the query, finds all matching docs, and returns the first 10
to the requesting node, B<IN ANY ORDER>.

=item *

The requesting node B<RETURNS ALL 50 DOCS IN ANY ORDER>.

=item *

It also returns a C<scroll_id> which (1) keeps track of what
results have already been returned and (2) keeps a consistent view of
the index state at the time of the intial query.

=item *

With this C<scroll_id>, we can keep pulling another 50 docs (ie
number_of_primary_shards * L</size>) until we have exhausted all the docs.

=back

=head3 But I really need sorting!

Do you?  Do you really? Why?  No user needs to page through all 5 million
of your matching results.

OK, so there may be situations where need to retrieve large numbers of sorted
results.  The trick here is to break them up into chunks. For instance, you
could request all docs created in October, then November etc. How you do it
really depends on your requirements.

=head2 delete()

TODO: Document

=head2 first()

TODO: Document

=head2 total()

TODO: Document

