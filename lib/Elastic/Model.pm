package Elastic::Model;

use Moose();
use Moose::Exporter();
use Carp;
use namespace::autoclean;

my $init_meta = Moose::Exporter->build_import_methods(
    install         => [qw(import unimport)],
    class_metaroles => { class => ['Elastic::Model::Meta::Class::Model'] },
    with_meta       => [qw(namespace analyzer tokenizer filter char_filter)],
);

#===================================
sub init_meta {
#===================================
    my $class = shift;
    my %p     = @_;
    Moose::Util::ensure_all_roles( $p{for_class},
        'Elastic::Model::Role::Model' );
    $class->$init_meta(%p);
}

#===================================
sub namespace {
#===================================
    my $meta   = shift;
    my $name   = shift or croak "No namespace name passed to namespace";
    my $params = ref $_[0] ? shift : {@_};

    my $types = $params->{types};
    croak "No types specified for namespace $name"
        unless $types && %$types;

    $meta->add_namespace( $name => $types );

    my $domains = $params->{domains} || [$name];
    $meta->add_domain($_ => $name)
        for ref $domains ? @$domains : $domains;
}

#===================================
sub analyzer    { shift->add_analyzer( shift,    {@_} ) }
sub tokenizer   { shift->add_tokenizer( shift,   {@_} ) }
sub filter      { shift->add_filter( shift,      {@_} ) }
sub char_filter { shift->add_char_filter( shift, {@_} ) }
#==================================

1;

# ABSTRACT: A NoSQL object-persistence framework for Moose using ElasticSearch as a backend.

=head1 DESCRIPTION

Elastic::Model is a NoSQL object-persistence framework for Moose using
ElasticSearch as a backend.  It aims to Do the Right Thing with minimal
extra code, but allows you to benefit from the full power of ElasticSearch
as soon as you are ready to use it.

=head1 SYNOPSIS

    package MyApp;

    use Moose;
    use Elastic::Model;

    has_domain 'myapp' => (
        types => {
            user => 'MyApp::User',
            post => 'MyApp::Post'
        }
    );


    # Setup custom analyzers

    filter 'edge_ngrams' => (
        type     => 'edgeNGram',
        min_gram => 2,
        max_gram => 10
    );

    analyzer 'edge_ngrams' => (
        tokenizer => 'standard',
        filter    => [ 'standard', 'lowercase', 'edge_ngrams' ]
    );



=head2 Using your model

    use MyApp();
    use ElasticSearch();

    my $es      = ElasticSearch->new( servers => 'es.domain.com:9200' );
    my $model   = MyApp->new( es => $es);

    my $domain  = $model->domain('myapp');
    my $scope   = $model->new_scope;

=head3 Create index in elasticsearch

    $domain->index('myapp_1')->create;

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

    use Moose;
    use Elastic::Model;

    has_domain 'my_domain' => (
        types => {
            foo => 'MyApp::Foo',
            bar => 'MyApp::Bar'
        }
    );

This applies L<Elastic::Model::Role::Model> to your model,
L<Elastic::Model::Meta::Model> to your model's metaclass and exports
functions which help you to configure your model.

A model must define one or more C<domains>, where a domain is like a
'namespace'.  Initially, a domain corresponds to an C<index> (or database)
in ElasticSearch, but later on, domains can be used to scale your application
when a single index is insufficient. See L<Elastic::Model::Manual::Scaling> for
more.

Each C<domain> must contain one or more C<types> (where a C<type> is like a
table in a relational database) and the class associated with that type.
For instance, objects of class C<MyApp::User> might be stored in type C<user>.

=head2 Specifying custom analyzers

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

=head3 char_filter

Character filters can change the text before it gets tokenized, for instance:

    char_filter 'my_mapping' => (
        type        => 'mapping',
        mappings    => ['ph=>f','qu=>q']
    );

=head3 tokenizer

A tokenizer breaks up the text into individual tokens or terms. For instance,
the C<pattern> tokenizer could be used to split text using a regex:

    tokenizer 'my_word_tokenizer' => (
        type        => 'pattern',
        pattern     => '\W+',          # splits on non-word chars
    );

=head3 filter

Any terms/tokens produced by the L</"tokenizer"> can the be passed through
multiple token filters.  For instance, each term could be broken down into
"edge ngrams" (eg 'foo' => 'f','fo','foo') for partial matching.

    filter 'my_ngrams' => (
        type        => 'edgeNGram',
        min_gram    => 1,
        max_gram    => 10,
    );

=head3 analyzer

Custom analyzers can be defined by combining character filters, a tokenizer and
token filters, some of which could be built-in, and some defined by the
keywords above.

For instance:

    analyzer 'partial_word_analyzer' => (
        type        => 'custom',
        char_filter => ['my_mapping'],
        tokenizer   => ['my_word_tokenizer'],
        filter      => ['lowercase','stop','my_ngrams']
    );


=cut

=head1 SEE ALSO

=head1 TODO

=head1 BUGS

None known

=head1 AUTHOR

Clinton Gormley, E<lt>clinton@traveljury.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Clinton Gormley

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut

