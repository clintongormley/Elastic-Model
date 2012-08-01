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
has 'search_quote_analyzer' => (
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

1;

__END__

# ABSTRACT: Add ElasticSearch specific keywords to your attribute definitions.

=head1 DESCRIPTION

L<Elastic::Model::Trait::Field> is automatically applied to all of your
attributes when you include C<use Elastic::Doc;> at the top of your doc
classes. This trait adds keywords to allow you to configure how each attribute
is indexed in ElasticSearch.

It also wraps all attribute accessors to ensure that Elastic::Doc objects
are properly inflated before any attribute is accessed.

See L<Elastic::Manual::Attributes> for an explanation of how to use these
keywords.

=head1 ATTRIBUTES

=head2 L<type|Elastic::Manual::Attributes/type>

=head2 L<mapping|Elastic::Manual::Attributes/mapping>

=head2 L<exclude|Elastic::Manual::Attributes/exclude>

=head2 L<include_in_all|Elastic::Manual::Attributes/include_in_all>

=head2 L<index|Elastic::Manual::Attributes/index>

=head2 L<store|Elastic::Manual::Attributes/store>

=head2 L<multi|Elastic::Manual::Attributes/multi>

=head2 L<index_name|Elastic::Manual::Attributes/index_name>

=head2 L<boost|Elastic::Manual::Attributes/boost>

=head2 L<null_value|Elastic::Manual::Attributes/null_value>

=head2 L<analyzer|Elastic::Manual::Attributes/analyzer>

=head2 L<index_analyzer|Elastic::Manual::Attributes/index_analyzer>

=head2 L<search_analyzer|Elastic::Manual::Attributes/search_analyzer>

=head2 L<search_quote_analyzer|Elastic::Manual::Attributes/search_quote_analyzer>

=head2 L<omit_norms|Elastic::Manual::Attributes/omit_norms>

=head2 L<omit_term_freq_and_positions|Elastic::Manual::Attributes/omit_term_freq_and_positions>

=head2 L<term_vector|Elastic::Manual::Attributes/term_vector>

=head2 L<format|Elastic::Manual::Attributes/format>

=head2 L<precision_step|Elastic::Manual::Attributes/precision_step>

=head2 L<geohash|Elastic::Manual::Attributes/geohash>

=head2 L<lat_lon|Elastic::Manual::Attributes/lat_lon>

=head2 L<geohash_precision|Elastic::Manual::Attributes/geohash_precision>

=head2 L<enabled|Elastic::Manual::Attributes/enabled>

=head2 L<dynamic|Elastic::Manual::Attributes/dynamic>

=head2 L<path|Elastic::Manual::Attributes/path>

=head2 L<include_in_parent|Elastic::Manual::Attributes/include_in_parent>

=head2 L<include_in_root|Elastic::Manual::Attributes/include_in_root>

=head2 L<deflator|Elastic::Manual::Attributes/deflator>

=head2 L<inflator|Elastic::Manual::Attributes/inflator>

=head2 L<include_attrs|Elastic::Manual::Attributes/include_attrs>

=head2 L<exclude_attrs|Elastic::Manual::Attributes/exclude_attrs>



