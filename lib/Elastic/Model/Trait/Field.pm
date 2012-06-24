package Elastic::Model::Trait::Field;

use Moose::Role;
use MooseX::Types::Moose qw(
    Str HashRef ArrayRef Bool Num Int CodeRef
);
use Elastic::Model::Types qw(
    FieldType IndexMapping TermVectorMapping MultiFields
    StoreMapping DynamicMapping PathMapping
);
use Carp;

use namespace::autoclean;

#===================================
around [
    '_inline_instance_get',   '_inline_instance_set',
    '_inline_instance_clear', '_inline_instance_has'
    ]
#===================================
    => sub {
    my ( $orig, $attr, $instance, @args ) = @_;
    my $inline = $attr->$orig( $instance, @args );
    unless ( $attr->exclude ) {
        $inline = <<"INLINE"
    do {
        $instance->_can_inflate && $instance->_inflate_doc;
        $inline
    }
INLINE
    }
    return $inline;
    };

#===================================
around [ 'get_value', 'set_value', 'clear_value', 'has_value' ]
#===================================
    => sub {
    my ( $orig, $attr, $instance, @args ) = @_;
    unless ( $attr->exclude ) {
        $instance->_can_inflate && $instance->_inflate_doc;
    }
    return $attr->$orig( $instance, @args );
    };

#===================================
has 'type' => (
#===================================
    isa       => FieldType,
    is        => 'ro',
    predicate => 'has_type'
);

#===================================
has 'mapping' => (
#===================================
    isa => HashRef [Str],
    is => 'ro'
);

#===================================
has 'exclude' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

#===================================
has 'include_in_all' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

#===================================
has 'index' => (
#===================================
    isa => IndexMapping,
    is  => 'ro'
);

#===================================
has 'store' => (
#===================================
    isa    => StoreMapping,
    is     => 'ro',
    coerce => 1
);

#===================================
has 'multi' => (
#===================================
    isa => MultiFields,
    is  => 'ro'
);

#===================================
has 'index_name' => (
#===================================
    isa => Str,
    is  => 'ro'
);

#===================================
has 'boost' => (
#===================================
    isa => Num,
    is  => 'ro'
);

#===================================
has 'null_value' => (
#===================================
    isa => Str,
    is  => 'ro'
);

# strings

#===================================
has 'analyzer' => (
#===================================
    isa => Str,
    is  => 'ro'
);

#===================================
has 'index_analyzer' => (
#===================================
    isa => Str,
    is  => 'ro'
);

#===================================
has 'search_analyzer' => (
#===================================
    isa => Str,
    is  => 'ro'
);

#===================================
has 'omit_norms' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

#===================================
has 'omit_term_freq_and_positions' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

#===================================
has 'term_vector' => (
#===================================
    isa => TermVectorMapping,
    is  => 'ro'
);

# dates

#===================================
has 'format' => (
#===================================
    isa => Str,
    is  => 'ro'
);

#===================================
has 'precision_step' => (
#===================================
    isa => Int,
    is  => 'ro'
);

# geo-point

#===================================
has 'geohash' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

#===================================
has 'lat_lon' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

#===================================
has 'geohash_precision' => (
#===================================
    isa => Int,
    is  => 'ro'
);

# object

#===================================
has 'enabled' => (
#===================================
    isa       => Bool,
    is        => 'ro',
    predicate => 'has_enabled'
);

#===================================
has 'dynamic' => (
#===================================
    isa => DynamicMapping,
    is  => 'ro'
);

#===================================
has 'path' => (
#===================================
    isa => PathMapping,
    is  => 'ro'
);

#===================================
has 'properties' => (
#===================================
    isa => HashRef [Str],
    is => 'ro'
);

# nested

#===================================
has 'include_in_parent' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

#===================================
has 'include_in_root' => (
#===================================
    isa => Bool,
    is  => 'ro'
);

# deflation

#===================================
has 'deflator' => (
#===================================
    isa => CodeRef,
    is  => 'ro'
);

#===================================
has 'inflator' => (
#===================================
    isa => CodeRef,
    is  => 'ro'
);

# esdocs

#===================================
has 'include_attrs' => (
#===================================
    isa => ArrayRef [Str],
    is => 'ro'
);

#===================================
has 'exclude_attrs' => (
#===================================
    isa => ArrayRef [Str],
    is => 'ro'
);

#===================================
before '_process_options' => sub {
#===================================
    my ( $class, $name, $opts ) = @_;
    if ( my $orig = $opts->{trigger} ) {
        ( 'CODE' eq ref $orig )
            || $class->throw_error(
            "Trigger must be a CODE ref on attribute ($name)",
            data => $opts->{trigger} );
        $opts->{trigger} = sub {
            my $self = shift;
            no warnings 'uninitialized';
            unless ( @_ == 2 && $_[1] eq $_[0] ) {
                $self->has_changed( $name, $_[1] );
            }
            $self->$orig(@_);
        };
    }
    else {

        $opts->{trigger} = sub {
            my $self = shift;
            no warnings 'uninitialized';
            unless ( @_ == 2 && $_[1] eq $_[0] ) {
                $self->has_changed( $name, $_[1] );
            }
        };
    }
};

1;

__END__

# ABSTRACT: Add ElasticSearch specific keywords to your attribute definitions.

=head1 SYNOPSIS

    package MyApp::User;

    use Elastic::Doc;

    has 'email' => (
        isa       => 'Str',
        is        => 'rw',
        multi => {
            untouched => { index    => 'not_analyzed' },
            ngrams    => { analyzer => 'edge_ngrams' }
        }
    );

    no Elastic::Doc;

=head1 DESCRIPTION

L<Elastic::Model::Trait::Field> is automatically applied to all of your
attributes when you include C<use Elastic::Doc;> at the top of your doc
classes. This traits adds keywords to allow you to configure how each attribute
is indexed in ElasticSearch.

Also see L<Elastic::Model::TypeMap::Default>.

=head1 GENERAL KEYWORDS

Also see L</"CUSTOM MAPPING, INFLATION AND DEFLATION">.

These keywords can be applied to any attribute type:

=head2 type

    has 'foo' => (
        is      => 'ro',
        type    => 'string',
    );

The C<type> of an attribute is usually determined by the Moose type constraint,
for instance C<< ( isa => 'Str' ) >> would set C<type> to C<string>, and
C<< ( isa => 'Int' ) >> would set C<type> to C<integer>.

You can use the C<type> setting to override the default. Possible values for
C<type> are: C<string>, C<integer>, C<long>, C<float>, C<double>, C<short>,
C<byte>, C<boolean>, C<binary>, C<object>, C<nested>, C<ip>, C<geo_point>
and  C<attachment>.

=head2 exclude

    has 'cache_key' => (
        is      => 'ro',
        exclude => 1,
        builder => '_generate_cache_key',
        lazy    => 1,
    );

If C<exclude> is true then the attribute will not be stored in ElasticSearch.
This is only useful for generated or temporary attributes. If you want
to store the attribute but make it not searchable, then you should use
the L</"index"> keyword instead.

=head2 include_in_all

    has 'secret' => (
        is              => 'ro',
        isa             => 'Str',
        include_in_all  => 0
    );

By default, all attributes (except those with C<< index => 'no' >>) are also
indexed in the special C<_all> field. This is intended to make it easy
to search for documents that contain a value in any field.  If you would
like to exclude a particular value from the C<_all> field, then specify
a false value for C<include_in_all>.

B<Note:> The C<_all> field has its own L</"analyzer"> - so the tokens that
are stored in the C<_all> field may be different from the tokens stored in
the attribute itself.

B<Note:> when C<include_in_all> is set on a field of type C<object>, its
value will propogate down to all attributes within the object.

=head2 index

    has 'tag' => (
        is      => 'rw',
        isa     => 'Str',
        index   => 'not_analyzed'
    );

The C<index> keyword controls how ElasticSearch will index your attribute.  It
accepts 3 values:

=over

=item *

C<no>: This attribute will not be indexed, and will thus not be searchable.

=item *

C<not_analyzed>: This attribute will be indexed using exactly the value
that you pass in, eg C<FoO> will be stored (and searchable) as C<FoO>.

=item *

C<analyzed>:    This attribute will be analyzed before being indexed. In other
words, the text value will be passed through the specified (or default)
L</"analyzer"> before being indexed. The analyzer will tokenize and pre-process
the text to produce 'terms'.  For example C<FoO BAR> would (depending on
the analyzer) be stored as the terms C<foo> and C<bar>.
This is the default for string fields (except for enums).

=back

=head2 store

    has 'big_field' => (
        is          => 'ro',
        isa         => 'Str',
        store       => 'yes'
    );


Individual fields can be stored (ie have their original value stored on disk).
This is not the same as whether the value is indexed or not (see L</"index">).
It just means that this individual value can be retrieved separately from the
others. C<stored> defaults to C<'no'> but can be set to C<'yes'>.

You almost never need this.  The C<_source> field (which is stored) contains
the hashref representing your whole object, and is returned by default when you
get or search for a document.  This means a single disk seek to load the
C<_source> field, rather than a disk seek (think 5ms) for every stored field!
It is much more efficient.

There are two situations where it might make sense to store a field separately:

=head3 Fast snippet highlighting

There are two highlighters available for
L<highlighting matching snippets|http://www.elasticsearch.org/guide/reference/api/search/highlighting.html>
in text fields: the C<highlighter>, which can be used on any analyzed text
field without any preparation,  and the C<fast-vector-highlighter> which is
faster (better for large text fields which require frequent highlighting),
but the field needs to be setup correctly before use:

    has 'big_field' => (
        is          => 'ro',
        isa         => 'Str',
        store       => 'yes',
        term_vector => 'with_positions_offsets'
    );

=head3 Retrieving large fields separately

If you have a VERY large field (eg a binary attachment) which is seldom accessed
then it may make sense to store that field separately, and to remove it from
the C<_source> field. That way the large field can be lazy-loaded when
necessary.

TODO: Allow attributes to be lazy loaded automatically.

=head2 boost

    has 'title' => (
        is      => 'rw',
        isa     => 'Str',
        boost   => 2
    );

A C<boost> makes a value "more relevant".  For instance, the words in the
C<title> field of a blog post are probably a better indicator of the topic
than the words in the C<content> field. You can boost a field at
search time and at index time. The benefit of boosting at search time, is that
your C<boost> is not fixed.  The benefit of boosting at C<index> time is
that the C<boost> value is carried over to the C<_all> field.

Also see L</"omit_norms">.

=head2 multi

    has 'name' => (
        is      => 'ro',
        isa     => 'Str',
        multi   => {
            sorting     => { index    => 'not_analyzed' },
            partial     => { analyzer => 'ngrams'       }
        }
    );

It is a common requirement to be able to use a single field in different
ways. For instance, with the C<name> field example above, we may want to:

=over

=item *

Do a full text search for C<Joe Bloggs>

=item *

Do a partial match on all names beginning with C<Blo>

=item *

Sort results alphabetically by name.

=back

A single field definition is insufficient in this case:  The standard analyzer
won't allow partial matching, and because it generates multiple terms/tokens,
it can't be used for sorting. (You can only sort on a single value).

This is where L<multi_fields|http://www.elasticsearch.org/guide/reference/mapping/multi-field-type.html>
are useful.  The same value can be indexed and queries in multiple ways. When
you specify a C<multi> mapping, each "sub-field" inherits the mapping of the
main field, so you only need to specify what is different.
The "sub-fields" can be referred to as eg C<name.partial> or C<name.sorting>
and the main field C<name> can also be referred to as C<name.name>.

Another benefit of multi-fields is that they can be added without reindexing
all of your data.

=head2 index_name

    has 'foo' => (
        is          => 'rw',
        isa         => 'Str',
        index_name  => 'bar'
    );

ElasticSearch uses dot-notation to refer to nested hashes. For instance, with
this data structure:

    {
        foo => {
            bar => {
                baz => 'xxx'
            }
        }
    }

... you could refer to the C<baz> value as C<baz> or as C<foo.bar.baz>.

Sometimes, you may want to specify a different name for a field.  For instance:

    {
        street => {
            name    => 'Oxford Street',
            number  => 1
        },
        town => {
            name    => 'London'
        }
    }

You can use the C<index_name> to distinguish C<town_name> from C<street_name>.

=head2 null_value

    has 'foo' => (
        is          => 'rw',
        isa         => 'Str',
        null_value  => 'none'
    );

If the attribute's value is C<undef> then the C<null_value> will be indexed
instead. This option is included for completeness, but isn't very useful.
Rather just leave the value as C<undef> and use the
L<exists|http://www.elasticsearch.org/guide/reference/query-dsl/exists-filter.html>
and L<missing|http://www.elasticsearch.org/guide/reference/query-dsl/missing-filter.html>
filters when you need to consider C<undef> values.

=cut

=head1 STRING KEYWORDS

These keywords are applicable only to fields of L</"type"> C<string>.

=head2 analyzer

    has 'email' => (
        is          => 'ro',
        isa         => 'Str',
        analyzer    => 'my_email_analyzer'
    );

Specify which analyzer (built-in or custom) to use at index time and at search
time. This is the equivalent of setting L</"index_analyzer"> and
L</"search_analyzer"> to the same value.

Also see L<Elastic::Manual::Analysis> for an explanation.

=head2 index_analyzer

    has 'email' => (
        is              => 'ro',
        isa             => 'Str',
        index_analyzer  => 'my_email_analyzer'
    );

Sets the L</"analyzer"> to use at index time only.

=head2 search_analyzer

    has 'email' => (
        is              => 'ro',
        isa             => 'Str',
        search_analyzer => 'my_email_analyzer'
    );

Sets the L</"analyzer"> to use at search time only.

=head2 omit_norms

    has 'status' => (
        is          => 'ro',
        isa         => 'Str',
        analyzer    => 'keyword',
        omit_norms  => 1
    );

Norms allow for index time L</"boost"> and for field length normalization
(shorter fields score higher).  This may not always be what you want. For
instance, a C<status> field may contain a single value that is never used
for relevance scoring, just for filtering (eg all docs where C<status> is
C<active>). Or, if the values in a field are short (eg name, email) then
the field length normalization may skew the results incorrectly.

You can turn off norms with C<omit_norms> set to true.

See L<http://www.lucidimagination.com/content/scaling-lucene-and-solr#d0e71>
for more discussion of C<omit_norms>.

=head2 omit_term_freq_and_positions

    has 'status' => (
        is                              => 'ro',
        isa                             => 'Str',
        analyzer                        => 'keyword',
        omit_term_freq_and_positions    => 1
    )

ElasticSearch normally stores the frequency and position of each term in
analyzed text. If you don't need this information, then you can turn it off,
and save space.

See L<http://www.lucidimagination.com/content/scaling-lucene-and-solr#d0e63>
for more discussion of C<omit_term_freq_and_positions>.

=head2 term_vector

    has 'text' => (
        is          => 'ro',
        isa         => 'Str',
        store       => 'yes',
        term_vector => 'with_positions_offsets',
    );

The full functionality of term vectors is not exposed via ElasticSearch, so
the only real value for now is for when you want to use the
C<fast-vector-highlighter>.  See L</"Fast snippet highlighting"> for an
explanation.  Allowed values are: C<no> (the default), C<yes>, C<with_offsets>,
C<with_positions> and C<with_positions_offsets>.

=head1 NUMERIC KEYWORDS

The following keyword applies only to fields of L</"type"> C<integer>,
C<long>, C<float>, C<double>, C<short> or C<byte>.

=head2 precision_step (numeric)

    has 'count' => (
        isa             => 'Int',
        precision_step  => 2,
    );

The C<precision_step> determines the number of terms generated for each
value (defaults to 4). The more terms, the faster the lookup, but the more
memory used.

=head1 DATE KEYWORDS

The following keywords apply only to fields of L</"type"> C<date>.
Dates in ElasticSearch are stored internally as long values containing
milliseconds since the epoch.

=head2 format

    has 'year_week' => (
        isa     => 'Str',
        type    => 'date',
        format  => 'basic_week_date'
    );

Date fields by default can parse (1) milliseconds since epoch
(2) yyyy/MM/dd HH:mm:ss Z or (3) yyyy/MM/dd Z.

If you would like to specify a different format, you can use of the
L<built-in formats|http://www.elasticsearch.org/guide/reference/mapping/date-format.html>
or a L<custom format|http://joda-time.sourceforge.net/api-release/org/joda/time/format/DateTimeFormat.html>.

=head2 precision_step (date)

    has 'count' => (
        isa             => 'Int',
        precision_step  => 2,
    );

The C<precision_step> determines the number of terms generated for each
value (defaults to 4). The more terms, the faster the lookup, but the more
memory used.

=head1 GEO-POINT KEYWORDS

The following keywords apply only to fields of L</"type"> C<geo_point>.

Geo-points are special fields for storing latitude/longitude.
L<Elastic::Model::Types> provides the L<Elastic::Model::Types/"GeoPoint">
type for convenience.

See L<http://www.elasticsearch.org/guide/reference/mapping/geo-point-type.html>
for more information about geo_point fields.

=head2 lat_lon

    has 'point' => (
        is      => 'ro',
        isa     => GeoPoint,
        lat_lon => 1
    );

By default, a geo-point is indexed as a lat-lon combination.  To index the
C<lat> and C<lon> fields as numeric fields as well, which is considered
good practice, as both the L<geo distance|http://www.elasticsearch.org/guide/reference/query-dsl/geo-distance-filter.html>
and L<bounding box|http://www.elasticsearch.org/guide/reference/query-dsl/geo-bounding-box-filter.html>
filters can either be executed using in memory checks, or using the indexed
lat lon values.  B<Note:> indexed lat lon only makes sense when there is a
single geo point value for the field, and not multiple values.

=head2 geohash

    has 'point' => (
        is      => 'ro',
        isa     => GeoPoint,
        geohash => 1,
    );

Set C<geohash> to true to index the L<geohash|http://en.wikipedia.org/wiki/Geohash>
value as well.

=head2 geohash_precision

    has 'point' => (
        is                  => 'ro',
        isa                 => GeoPoint,
        geohash             => 1,
        geohash_precision   => 8,
    );

The C<geohash_precision> determines how accurate the geohash will be -
defaults to 12.

=head1 OBJECT KEYWORDS

The following keywords apply only to fields of L</"type"> C<object> and C<nested>.

Hashrefs (and objects which have been serialised to hashrefs) are considered
to be "objects", as in JSON objects. Your doc class is serialized to a
JSON object/hash, which is known as the L<root_object|http://www.elasticsearch.org/guide/reference/mapping/root-object-type.html>.
The mapping for the root object can be configured with L<Elastic::Doc/"type_mapping">.

Your doc class may have attributes which are hash-refs, or objects, which
may themselves contain hash-refs or objects. Multi-level data structures are
allowed.

The mapping for these structures should be automatically generated, but
these keywords give you some extra control:

=head2 enabled

    has 'foo' => (
        is      => 'ro',
        isa     => 'HashRef',
        enabled => 0
    );

Setting C<enabled> to false disables the indexing of any value in the object.
Defaults to true.

=head2 dynamic

    has 'foo' => (
        is      => 'ro',
        isa     => 'HashRef',
        dynamic => 1
    );

ElasticSearch defaults to trying to detect field types dynamically, but
this can lead to mistakes, eg is C<"123"> a C<string> or a C<long>?
Elastic::Model turns off this dynamic detection, and instead uses Moose's
type constraints to determine what type each field should have.

If you know what you're doing, you can set C<dynamic> to  C<1> (auto-detect
new field types), C<0> (ignore new fields) or C<'strict'> (throw an error
if an unknown field is included).

=head2 path

    package MyApp::Types;

    use MooseX::Types -declare 'FullName';

    use MooseX::Types::Moose qw(Str);
    use MooseX::Types::Structured qw(Dict);

    subtype Fullname,
    as Dict[
        first   => Str,
        last    => Str
    ];


    package MyApp::Couple;

    use Moose;
    use MyApp::Types qw(FullName);

    has 'husband' => (
        is      => 'ro',
        isa     => FullName,
        path    => 'just_name'
    );

    has 'wife' => (
        is      => 'ro',
        isa     => FullName,
        path    => 'full'
    );

The C<path> keyword accepts the values C<full> and C<just_name>.  By default,
nested attributes can be referenced by just their name, or by their path,
using dot-notation, eg C<wife.first>, or C<couple.wife.first>.

The C<path> setting, which defaults to C<full> (eg C<wife.first>) can be
set to C<just_name>, in which case eg the name C<husband.first> won't be defined.

The C<path> keyword can also be combined with the L</"index_name"> keyword.

=head2 properties

    has 'name' => (
        is          => 'ro',
        isa         => 'HashRef',
        properties  => {
            first   => { type    => 'string'},
            last    => { type    => 'string'},
        }
    );

The C<properties> keyword can be used to specify the mapping for each field
in raw ElasticSearch syntax.

=head1 NESTED OBJECT KEYWORDS

The following keywords apply only to fields of L</"type"> C<nested>.

C<nested> fields are a sub-class of C<object> fields, that are useful when
your attribute can contain multiple values.

First an explanation.  Consider this data structure:

    {
        person  => [
            { first => 'John', last => 'Smith' },
            { first => 'Mary', last => 'Smith' },
            { first => 'Mary', last => 'Jones' }
        ]
    }

If the C<person> field is of type C<object>, then the above data structure is
flattened into something more like this:

    {
        'person.first' => ['John','Mary','Mary'],
        'person.last'  => ['Smith','Smith','Jones']
    }

With this structure it is impossible to run queries that depend on matching
on attributes of a SINGLE C<person> object.  For instance, a query asking
for docs that have a C<person> who has C<(first == John and last == Jones)>
would incorrectly match this document.

Nested objects are the solution to this problem.  When an attribute is
marked as L</"type"> C<nested>, then ElasticSearch creates each object
as a separate-but-related hidden document. These nested objects can be queried with the
L<nested query|http://www.elasticsearch.org/guide/reference/query-dsl/nested-query.html>
and the L<nested filter|http://www.elasticsearch.org/guide/reference/query-dsl/nested-filter.html>.

=head2 include_in_parent

    has 'person' => (
        is                  => 'ro',
        isa                 => ArrayRef[Person],
        type                => 'nested',
        include_in_parent   => 1,
    );

If you would also like the data from the nested objects to be indexed in
their containing object (as in the first data structure above), then
set C<include_in_parent> to true.

=head2 include_in_root

    has 'person' => (
        is                  => 'ro',
        isa                 => ArrayRef[Person],
        type                => 'nested',
        include_in_root     => 1,
    );

Object can be nested inside objects which are nested inside objects etc. The
C<include_in_root> keyword does the same as the L</"include_in_parent"> keyword,
but refers to the top-most document, rather than the direct parent.

=head1 Elastic::Doc CLASS KEYWORDS

You can have attributes in one class that refer to another L<Elastic::Doc>
class.  For instance, a C<MyApp::Post> object could have, as an attribute,
the C<MyApp::User> object to whome the post belongs.

You may want to store just the L<Elastic::Model::UID> of the C<user> object,
or you may want to include the user's name and email address, so that you
can search for posts by a user named "Joe Bloggs". You can't do joins in
a NoSQL database, so you need to denormalize your data.

The following keywords apply only to fields which C<isa> class which does
L<Elastic::Model::Meta::Class::Doc> (ie classes that use L<Elastic::Doc>).


=head2 include_attrs

    has 'user' => (
        is            => 'ro',
        isa           => 'MyApp::User',
        include_attrs => ['name','email']
    );

The above declaration will index the C<user> object's UID, plus the C<name>
and C<email> attributes.  If C<include_attrs> is not specified, then all
the attributes from the C<user> object will be indexed. If C<include_attrs>
is set to an empty array ref C<[]> then no attributes other than the UID
will be indexed.

=head2 exclude_attrs

    has 'user' => (
        is            => 'ro',
        isa           => 'MyApp::User',
        exclude_attrs => ['secret']
    );

The above declaration will index all the C<user> attributes, except for the
attribute C<secret>.

=head1 ATTACHMENT KEYWORDS

TODO

=head1 CUSTOM MAPPING, INFLATION AND DEFLATION

The preferred way to specify the mapping and how to deflate and inflate
an attribute is by specifying an C<isa> type constraint and adding a
L<typemap entry|Elastic::Model::TypeMap::Default>.

However, you can provide custom values with the following:

=head2 mapping

    has 'foo' => (
        is      => 'ro',
        type    => 'string',
        mapping => { index => 'no' },
    );

You can specify a custom C<mapping> directly in the attribute, which will be
used instead of the typemap entry that would be generated.  Any other
keywords that you specify (eg L</"type">) will be added to your C<mapping>.

=head2 deflator

    has 'foo' => (
        is       => 'ro',
        type     => 'string',
        deflator => sub { my $val = shift; return my_deflator($val) },
    );

You can specify a custom C<deflator> directly in the attribute. It should
return C<undef>, a string, or an unblessed data structure that can be converted
to JSON.

=head2 inflator

    has 'foo' => (
        is       => 'ro',
        type     => 'string',
        inflator => sub { my $val = shift; return my_inflator($val) },
    );

You can specify a custom C<inflator> directly in the attribute. It should
be able to reinflate the original value from the plain data structure that
is stored in ElasticSearch.

