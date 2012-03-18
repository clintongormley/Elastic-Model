package Elastic::Model::Trait::Field;

use Moose::Role;
use MooseX::Types::Moose qw(:all);
use Elastic::Model::Types qw(
    FieldType IndexMapping TermVectorMapping MultiFields
    StoreMapping DynamicMapping PathMapping
);
use Carp;

use namespace::autoclean;

has 'type' => ( isa => FieldType, is => 'ro' );
has 'mapping' => ( isa => HashRef [Str], is => 'ro' );
has 'exclude' => ( isa => Bool, is => 'ro' );

has 'include_in_all' => ( isa => Bool, is => 'ro' );

has 'index' => ( isa => IndexMapping, is => 'ro' );
has 'store' => ( isa => StoreMapping, is => 'ro', coerce => 1 );
has 'multi' => ( isa => MultiFields,  is => 'ro' );

has 'index_name' => ( isa => Str, is => 'ro' );
has 'boost'      => ( isa => Num, is => 'ro' );
has 'null_value' => ( isa => Str, is => 'ro' );

# strings
has 'analyzer'                     => ( isa => Str,  is => 'ro' );
has 'index_analyzer'               => ( isa => Str,  is => 'ro' );
has 'search_analyzer'              => ( isa => Str,  is => 'ro' );
has 'omit_norms'                   => ( isa => Bool, is => 'ro' );
has 'omit_term_freq_and_positions' => ( isa => Bool, is => 'ro' );
has 'term_vector' => ( isa => TermVectorMapping, is => 'ro' );
sub omit_tfp { shift->omit_term_freq_and_positions(@_) }

# dates
has 'format'         => ( isa => Str, is => 'ro' );
has 'precision_step' => ( isa => Int, is => 'ro' );

# geo-point
has 'geohash'           => ( isa => Bool, is => 'ro' );
has 'lat_lon'           => ( isa => Bool, is => 'ro' );
has 'geohash_precision' => ( isa => Int,  is => 'ro' );

# object
has 'enabled' => ( isa => Bool, is => 'ro', predicate => 'has_enabled' );
has 'dynamic' => ( isa => DynamicMapping, is => 'ro' );
has 'path'    => ( isa => PathMapping,    is => 'ro' );
has 'properties' => ( isa => HashRef [Str], is => 'ro' );

# nested
has 'include_in_parent' => ( isa => Bool, is => 'ro' );
has 'include_in_root'   => ( isa => Bool, is => 'ro' );

# deflation
has 'deflator' => ( isa => CodeRef, is => 'ro' );
has 'inflator' => ( isa => CodeRef, is => 'ro' );

# esdocs
has 'include_attrs' => ( isa => ArrayRef [Str], is => 'ro' );
has 'exclude_attrs' => ( isa => ArrayRef [Str], is => 'ro' );
has 'deflate_attrs' => (
    isa => ArrayRef [Str],
    is => 'ro',
    writer   => 'set_deflate_attrs',
    init_arg => undef
);

has '_wrapped_methods' => (
    isa     => HashRef,
    traits  => ['Hash'],
    handles => { method_wrapped => 'accessor' },
    is      => 'ro',
    default => sub { {} }
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
