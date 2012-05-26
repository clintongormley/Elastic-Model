package Elastic::Model;

use Moose();
use Moose::Exporter();
use Carp;
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    class_metaroles => { class => ['Elastic::Model::Meta::Class::Model'] },
    with_meta       => [
        qw(has_namespace has_type_map override_classes
            has_analyzer has_tokenizer has_filter has_char_filter)
    ],
    base_class_roles => ['Elastic::Model::Role::Model'],
    also             => 'Moose',
);

#===================================
sub has_namespace {
#===================================
    my $meta   = shift;
    my $name   = shift or croak "No namespace name passed to namespace";
    my $params = ref $_[0] ? shift : {@_};

    my $types = $params->{types};
    croak "No types specified for namespace $name"
        unless $types && %$types;

    $meta->add_namespace( $name => $types );

    my $domains = $params->{domains} || [$name];
    $meta->add_domain( $_ => $name ) for ref $domains ? @$domains : $domains;
}

#===================================
sub has_type_map { shift->set_class( 'type_map', @_ ) }
#===================================

#===================================
sub override_classes {
#===================================
    my $meta = shift;
    my %classes = ref $_[0] eq 'HASHREF' ? %{ shift() } : @_;
    for ( keys %classes ) {
        croak "Unknown arg for classes ($_)"
            unless $meta->get_class($_);
        $meta->set_class( $_ => $classes{$_} );
    }
}

#===================================
sub has_analyzer    { shift->add_analyzer( shift,    {@_} ) }
sub has_tokenizer   { shift->add_tokenizer( shift,   {@_} ) }
sub has_filter      { shift->add_filter( shift,      {@_} ) }
sub has_char_filter { shift->add_char_filter( shift, {@_} ) }
#==================================

1;

# ABSTRACT: A NoSQL object-persistence framework for Moose using ElasticSearch as a backend.

=head1 DESCRIPTION

Elastic::Model is a NoSQL object-persistence framework for Moose using
ElasticSearch as a backend.  It aims to Do the Right Thing with minimal
extra code, but allows you to benefit from the full power of ElasticSearch
as soon as you are ready to use it.

=head1 INTRODUCTION TO Elastic::Model

If you are not familiar with L<Elastic::Model>, you should start by reading
L<Elastic::Manual::Intro>.

=head1 SYNOPSIS

    package MyApp;

    use Elastic::Model;

    has_namespace 'myapp' => (
        types => {
            user => 'MyApp::User',
            post => 'MyApp::Post'
        },
        # domains => ['myapp']
    );

    has_type_map 'MyApp::TypeMap';

    # Setup custom analyzers

    has_filter 'edge_ngrams' => (
        type     => 'edgeNGram',
        min_gram => 2,
        max_gram => 10
    );

    has_analyzer 'edge_ngrams' => (
        tokenizer => 'standard',
        filter    => [ 'standard', 'lowercase', 'edge_ngrams' ]
    );

    no Elastic::Model;


=head2 Using your model

    use MyApp();
    use ElasticSearch();

    my $es      = ElasticSearch->new( servers => 'es.domain.com:9200' );
    my $model   = MyApp->new( es => $es);

    my $domain  = $model->domain('myapp');
    my $scope   = $model->new_scope;

=head3 Create index in elasticsearch

    $domain->admin->create_index;

=head3 Create an object

    my $user    = $domain->new_doc( user => { name => 'Clinton' })->save;

=head3 Retrieve an object by UID

    my $user_id = $user->uid;
    $user       = $domain->get($uid);

=head3 Create an object which refers to another object

    my $post    = $domain->new_doc(
        post => {
            title   => "An interesting post",
            body    => "Lorem ipsum",
            user    => $user
        }
    );

    $post->save;

=head3 Reusable views

    my $posts   = $domain->view->type('post');

=head3 Full text search

    my $results = $posts->queryb({
        title       => 'intere',
        'user.name' => 'clinton',
        created     => { '>' => '2012-01-01' }
    })->search;

    say "Found ".$results->total." results";

    while (my $post = $results->next_doc) {
        say   "Title: "
            . $post->title
            . ", by "
            . $post->user->name;
    }

=cut

=head1 USING Elastic::Model

Your application needs a C<model> class to handle the relationship between
your object classes and the ElasticSearch cluster.

Your model class is most easily defined as follows:

    package MyApp;

    use Elastic::Model;

    has_namespace 'myapp' => (
        types => {
            foo => 'MyApp::Foo',
            bar => 'MyApp::Bar'
        },
        # domains => ['myapp']
    );

    no Elastic::Model;

This applies L<Elastic::Model::Role::Model> to your model,
L<Elastic::Model::Meta::Model> to your model's metaclass and exports
functions which help you to configure your model.

Your model must define at least one L<namespace|Elastic::Manual::Terminology/Namespace>,
which tells Elastic::Model which
L<type|Elastic::Manual::Terminology/Type> (like a table in a DB) should be
handled by which of your classes.  So the above declaration says that objects
of class C<MyApp::User> will be stored in the C<user> type in ElasticSearch.

Your model must also define at least one L<domain|Elastic::Manual::Terminology/Domain>
(which defaults to the C<name> of the namespace). A C<domain> can be an
L<index|Elastic::Manual::Terminology/Index> (like a database in a relational DB)
or an L<alias|Elastic::Manual::Terminology/Alias> (which points to one or
more indices). It doesn't have to exist yet.

=head2 Custom TypeMap

Elastic::Model uses a L<TypeMap|Elastic::Model::TypeMap::Default> to figure
out how to inflate and deflate your objects, and how to configure them
in ElasticSearch.

You can specify your own TypeMap using:

    has_type_map 'MyApp::TypeMap';

See L<Elastic::Model::TypeMap::Base> for instructions on how to define
your own type-map classes.

=head2 Custom analyzers

Analysis is the process of converting full text into C<terms> or C<tokens> and
is one of the things that gives full text search its power.  When storing text
in the ElasticSearch index, the text is first analyzed into terms/tokens.
Then, when searching, search keywords go through the same analysis process
to produce the terms/tokens which are then searched for in the index.

Choosing the right analyzer for each field gives you enormous control over
how your data can be queried.

There are a large number of built-in analyzers available, but frequently
you will want to define custom analyzers, which consist of:

=over

=item *

zero or more character filters

=item *

a tokenizer

=item *

zero or more token filters

=back

L<Elastic::Model> provides sugar to make it easy to specify custom analyzers:

=head3 has_char_filter

Character filters can change the text before it gets tokenized, for instance:

    has_char_filter 'my_mapping' => (
        type        => 'mapping',
        mappings    => ['ph=>f','qu=>q']
    );

=head3 has_tokenizer

A tokenizer breaks up the text into individual tokens or terms. For instance,
the C<pattern> tokenizer could be used to split text using a regex:

    has_tokenizer 'my_word_tokenizer' => (
        type        => 'pattern',
        pattern     => '\W+',          # splits on non-word chars
    );

=head3 has_filter

Any terms/tokens produced by the L</"tokenizer"> can the be passed through
multiple token filters.  For instance, each term could be broken down into
"edge ngrams" (eg 'foo' => 'f','fo','foo') for partial matching.

    has_filter 'my_ngrams' => (
        type        => 'edgeNGram',
        min_gram    => 1,
        max_gram    => 10,
    );

=head3 has_analyzer

Custom analyzers can be defined by combining character filters, a tokenizer and
token filters, some of which could be built-in, and some defined by the
keywords above.

For instance:

    has_analyzer 'partial_word_analyzer' => (
        type        => 'custom',
        char_filter => ['my_mapping'],
        tokenizer   => ['my_word_tokenizer'],
        filter      => ['lowercase','stop','my_ngrams']
    );

=head2 Overriding Core Classes

If you would like to override any of the core classes used by L<Elastic::Model>,
then you can do so as follows:

    override_classes (
        domain  => 'MyApp::Domain',
        store   => 'MyApp::Store'
    );

The defaults are:

=over

=item *

C<domain> C<--------------> L<Elastic::Model::Domain>

=item *

C<store> C<---------------> L<Elastic::Model::Store>

=item *

C<view> C<----------------> L<Elastic::Model::View>

=item *

C<scope> C<---------------> L<Elastic::Model::Scope>

=item *

C<results> C<-------------> L<Elastic::Model::Results>

=item *

C<scrolled_results> C<----> L<Elastic::Model::Results::Scrolled>

=item *

C<result> C<--------------> L<Elastic::Model::Result>

=back
