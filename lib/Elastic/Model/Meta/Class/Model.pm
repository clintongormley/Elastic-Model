package Elastic::Model::Meta::Class::Model;

use Moose::Role;
use List::Util ();
use MooseX::Types::Moose qw(:all);
use Carp;
use Data::Dump qw(pp);
use namespace::autoclean;

my %defaults = (
    analyzer  => {},
    tokenizer => {},
);

for my $k (qw(namespace domain char_filter analyzer filter tokenizer)) {
    my %default = %{ $defaults{$k} || {} };
#===================================
    has "${k}s" => (
#===================================
        is      => 'ro',
        traits  => ['Hash'],
        isa     => HashRef,
        default => sub { \%default },
        handles => {
            $k          => 'get',
            "add_${k}"  => 'set',
            "has_${k}"  => 'exists',
            "all_${k}s" => 'keys',
        }
    );
    next if $k eq 'domain' || $k eq 'namespace';

#===================================
    before "add_$k" => sub {
#===================================
        my $class = shift;
        my %params = ref $_[0] ? { shift() } : @_;
        for my $defn ( values %params ) {
            my $type = $defn->{type} || 'custom';
            return if $type eq 'custom' and $k eq 'analyzer';
            croak "Unknown type '$type' in $k:\n" . pp( \%params ) . "\n"
                unless $class->is_default( $k, $type );
        }
    };
}

no Moose;

our %DefaultAnalysis = (
    char_filter => { map { $_ => 1 } qw(html_strip mapping) },
    filter      => +{
        map { $_ => 1 }
            qw(
            standard asciifolding length lowercase nGram edgeNGram
            porterStem shingle stop word_delimiter snowball kstem phonetic
            synonym dictionary_decompounder hyphenation_decompounder
            reverse elision trim truncate unique pattern_replace
            icu_normalizer icu_folding icu_collation
            )
    },
    tokenizer => {
        map { $_ => 1 }
            qw(
            edgeNGram keyword letter lowercase nGram standard
            whitespace pattern uax_url_email path_hierarchy
            )
    },
    analyzer => {
        map { $_ => 1 }
            qw(
            standard simple whitespace stop keyword pattern snowball
            arabic armenian basque brazilian bulgarian catalan chinese
            cjk czech danish dutch english finnish french galician german
            greek hindi hungarian indonesian italian latvian
            norwegian persian portuguese romanian russian spanish swedish
            turkish thai
            )
    }
);

#===================================
sub is_default {
#===================================
    my $self = shift;
    my $type = shift || '';
    croak "Unknown type '$type' passed to is_default()"
        unless exists $DefaultAnalysis{$type};
    my $name = shift or croak "No $type name passed to is_default";
    return exists $DefaultAnalysis{$type}{$name};
}

#===================================
sub analysis_for_mappings {
#===================================
    my $self     = shift;
    my $mappings = shift;

    my %analyzers;
    for my $type ( keys %$mappings ) {
        for my $name ( _required_analyzers( $mappings->{$type} ) ) {
            next
                if exists $analyzers{$name}
                    || $self->is_default( 'analyzer', $name );
            $analyzers{$name} = $self->analyzer($name)
                or die
                "Unknown analyzer '$name ' required by type '$type' in class "
                . $self->class_for_type($type);    ## TODO: wrong method
        }
    }
    return unless %analyzers;

    my %analysis = ( analyzer => \%analyzers );
    for my $type (qw(tokenizer filter char_filter )) {
        my %defn;
        for my $analyzer_name ( keys %analyzers ) {
            my $vals = $analyzers{$analyzer_name}{$type} or next;
            for my $name ( ref $vals ? @$vals : $vals ) {
                next
                    if exists $defn{$name}
                        || $self->is_default( $type, $name );
                $defn{$name} = $self->$type($name)
                    or die
                    "Unknown $type '$name' required by analyzer '$analyzer_name'";
            }
        }
        $analysis{$type} = \%defn if %defn;
    }
    return \%analysis;
}

#===================================
sub _required_analyzers {
#===================================
    my @analyzers;
    while (@_) {
        my $mapping = shift or next;
        my @sub = (
            values %{ $mapping->{fields} || {} },
            values %{ $mapping->{properties} || {} }
        );

        push @analyzers, _required_analyzers(@sub),
            map { $mapping->{$_} } grep /analyzer/, keys %$mapping;
    }

    return @analyzers;
}

our $Counter = 1;
#===================================
sub wrapped_class_name {
#===================================
    return 'Elastic::Model::__WRAPPED_' . $Counter++ . '_::' . $_[1];
}

1;

__END__

# ABSTRACT: A meta-class for Models

=head1 DESCRIPTION

Holds information about your model: domains and their types,
and char_filters, tokenizers, filters and analyzers for analysis.

You shouldn't need to touch anything in this class.

=head1 METHODS

=head2 is_default()

    $bool = $meta->is_default($type => $name);

Returns C<true> if C<$name> is a C<$type> (analyzer, tokenizer,
filter, char_filter) available in ElasticSearch by default.


=head3 Default analyzers

L<standard|http://www.elasticsearch.org/guide/reference/index-modules/analysis/standard-analyzer.html>,
L<simple|http://www.elasticsearch.org/guide/reference/index-modules/analysis/simple-analyzer.html>,
L<whitespace|http://www.elasticsearch.org/guide/reference/index-modules/analysis/whitespace-analyzer.html>,
L<stop|http://www.elasticsearch.org/guide/reference/index-modules/analysis/stop-analyzer.html>,
L<keyword|http://www.elasticsearch.org/guide/reference/index-modules/analysis/keyword-analyzer.html>,
L<pattern|http://www.elasticsearch.org/guide/reference/index-modules/analysis/pattern-analyzer.html>,
L<snowball|http://www.elasticsearch.org/guide/reference/index-modules/analysis/snowball-analyzer.html>,
and the L<language|http://www.elasticsearch.org/guide/reference/index-modules/analysis/lang-analyzer.html>
analyzers:  C<arabic>, C<armenian>, C<basque>, C<brazilian>, C<bulgarian>,
C<catalan>, C<chinese>, C<cjk>, C<czech>, C<danish>, C<dutch>, C<english>,
C<finnish>, C<french>, C<galician>, C<german>, C<greek>, C<hindi>, C<hungarian>,
C<indonesian>, C<italian>, C<latvian>, C<norwegian>, C<persian>,
C<portuguese>, C<romanian>, C<russian>, C<spanish>, C<swedish>,
C<thai>, C<turkish>

=head3 Default tokenizers

L<edgeNGram|http://www.elasticsearch.org/guide/reference/index-modules/analysis/edgengram-tokenizer.html>,
L<keyword|http://www.elasticsearch.org/guide/reference/index-modules/analysis/keyword-tokenizer.html>,
L<letter|http://www.elasticsearch.org/guide/reference/index-modules/analysis/letter-tokenizer.html>,
L<lowercase|http://www.elasticsearch.org/guide/reference/index-modules/analysis/lowercase-tokenizer.html>,
L<nGram|http://www.elasticsearch.org/guide/reference/index-modules/analysis/ngram-tokenizer.html>,
L<path_hierarchy|http://www.elasticsearch.org/guide/reference/index-modules/analysis/pathhierarchy-tokenizer.html>,
L<pattern|http://www.elasticsearch.org/guide/reference/index-modules/analysis/pattern-tokenizer.html>,
L<standard|http://www.elasticsearch.org/guide/reference/index-modules/analysis/standard-tokenizer.html>,
L<uax_url_email|http://www.elasticsearch.org/guide/reference/index-modules/analysis/uaxurlemail-tokenizer.html>,
L<whitespace|http://www.elasticsearch.org/guide/reference/index-modules/analysis/whitespace-tokenizer.html>

=head3 Default token filters

L<asciifolding|http://www.elasticsearch.org/guide/reference/index-modules/analysis/asciifolding-tokenfilter.html>,
L<dictionary_decompounder|http://www.elasticsearch.org/guide/reference/index-modules/analysis/compound-word-tokenfilter.html>,
L<edgeNGram|http://www.elasticsearch.org/guide/reference/index-modules/analysis/edgengram-tokenfilter.html>,
L<elision|http://www.elasticsearch.org/guide/reference/index-modules/analysis/elision-tokenfilter.html>,
L<hyphenation_decompounder|http://www.elasticsearch.org/guide/reference/index-modules/analysis/compound-word-tokenfilter.html>,
L<icu_collation|http://www.elasticsearch.org/guide/reference/index-modules/analysis/icu-plugin.html>,
L<icu_folding|http://www.elasticsearch.org/guide/reference/index-modules/analysis/icu-plugin.html>,
L<icu_normalizer|http://www.elasticsearch.org/guide/reference/index-modules/analysis/icu-plugin.html>,
L<kstem|http://www.elasticsearch.org/guide/reference/index-modules/analysis/kstem-tokenfilter.html>,
L<length|http://www.elasticsearch.org/guide/reference/index-modules/analysis/length-tokenfilter.html>,
L<lowercase|http://www.elasticsearch.org/guide/reference/index-modules/analysis/lowercase-tokenfilter.html>,
L<nGram|http://www.elasticsearch.org/guide/reference/index-modules/analysis/ngram-tokenfilter.html>,
L<pattern_replace|http://www.elasticsearch.org/guide/reference/index-modules/analysis/pattern_replace-tokenfilter.html>,
L<phonetic|http://www.elasticsearch.org/guide/reference/index-modules/analysis/phonetic-tokenfilter.html>,
L<porterStem|http://www.elasticsearch.org/guide/reference/index-modules/analysis/porterstem-tokenfilter.html>,
L<reverse|http://www.elasticsearch.org/guide/reference/index-modules/analysis/reverse-tokenfilter.html>,
L<shingle|http://www.elasticsearch.org/guide/reference/index-modules/analysis/shingle-tokenfilter.html>,
L<snowball|http://www.elasticsearch.org/guide/reference/index-modules/analysis/snowball-tokenfilter.html>,
L<standard|http://www.elasticsearch.org/guide/reference/index-modules/analysis/standard-tokenfilter.html>,
L<stop|http://www.elasticsearch.org/guide/reference/index-modules/analysis/stop-tokenfilter.html>,
L<synonym|http://www.elasticsearch.org/guide/reference/index-modules/analysis/synonym-tokenfilter.html>,
L<trim|http://www.elasticsearch.org/guide/reference/index-modules/analysis/trim-tokenfilter.html>,
L<truncate|http://www.elasticsearch.org/guide/reference/index-modules/analysis/truncate-tokenfilter.html>,
L<unique|http://www.elasticsearch.org/guide/reference/index-modules/analysis/word-delimiter-tokenfilter.html>,
L<word_delimiter|http://www.elasticsearch.org/guide/reference/index-modules/analysis/word-delimiter-tokenfilter.html>


=head3 Default character filters

L<html_strip|http://www.elasticsearch.org/guide/reference/index-modules/analysis/htmlstrip-charfilter.html>,
L<mapping|http://www.elasticsearch.org/guide/reference/index-modules/analysis/mapping-charfilter.html>

=head2 analysis_for_mappings()

    $analysis = $meta->analysis_for_mappings($mappings)

Used to generate the C<analysis> settings for an index, based on which
analyzers are used in the C<mappings> for all C<types> in the index.

=head1 ATTRIBUTES

=head2 domains

A hash ref containing all domains plus their configuration, eg:

    {
        myapp => {
            types => {
                user => 'MyApp::User'
            }
        }
    }

=head3 domains()

    $domains = $meta->domains();

=head3 domain()

    $config = $meta->domain($name)

=head3 has_domain()

    $bool = $meta->has_domain($name)

=head3 add_domain()

    $meta->add_domain($name => $config);

=head3 all_domains()

    @names = $meta->all_domains

=head2 analyzers

A hash ref containing all analyzers plus their configuration, eg:

    {
        my_analyzer => {
            type        => 'custom',
            tokenizer   => 'standard',
            filter      => ['lower']
        }
    }

Accessors:

=head3 analyzers()

    $analyzers = $meta->analyzers();

=head3 analyzer()

    $config = $meta->analyzer($name)

=head3 has_analyzer()

    $bool = $meta->has_analyzer($name)

=head3 add_analyzer()

    $meta->add_analyzer($name => $config);

=head3 all_analyzers()

    @names = $meta->all_analyzers

=head2 tokenizers

A hash ref containing all tokenizers plus their configuration, eg:

    {
        my_tokenizer => {
            type    => 'pattern',
            pattern => '\W'
        }
    }

Accessors:

=head3 tokenizers()

    $tokenizers = $meta->tokenizers();

=head3 tokenizer()

    $config = $meta->tokenizer($name)

=head3 has_tokenizer()

    $bool = $meta->has_tokenizer($name)

=head3 add_tokenizer()

    $meta->add_tokenizer($name => $config);

=head3 all_tokenizers()

    @names = $meta->all_tokenizers

=head2 filters

A hash ref containing all filters plus their configuration, eg:

    {
        my_filter => {
            type        => 'edgeNGram',
            min_gram    => 1,
            max_gram    => 20
        }
    }

Accessors:

=head3 filters()

    $filters = $meta->filters();


=head3 filter()

    $config = $meta->filter($name)

=head3 has_filter()

    $bool = $meta->has_filter($name)

=head3 add_filter()

    $meta->add_filter($name => $config);

=head3 all_filters()

    @names = $meta->all_filters

=head2 char_filters

A hash ref containing all char_filters plus their configuration, eg:

    {
        my_char_filter => {
            type        => 'mapping',
            mappings    => ['ph=>f','qu=>q']
        }
    }

Accessors:

=head3 char_filters()

    $char_filters = $meta->char_filters();

=head3 char_filter()

    $config = $meta->char_filter($name)

=head3 has_char_filter()

    $bool = $meta->has_char_filter($name)

=head3 add_char_filter()

    $meta->add_char_filter($name => $config);

=head3 all_char_filters()

    @names = $meta->all_char_filters

=head2 wrapped_class_name()

    $new_class = $meta->wrapped_class_name($old_class);

Generates a semi-anonymous classname with the format
C<Elastic::Model::__WRAPPED_::$n>


