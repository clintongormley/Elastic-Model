package ESModel::Trait::Field;

use Moose::Role;
use MooseX::Types::Moose qw(:all);
use ESModel::Doc::Deflator qw(find_deflator find_inflator);
use ESModel::Types qw(
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

# dates
has 'format'         => ( isa => Str, is => 'ro' );
has 'precision_step' => ( isa => Int, is => 'ro' );

# geo-point
has 'geohash'           => ( isa => Bool, is => 'ro' );
has 'lat_lon'           => ( isa => Bool, is => 'ro' );
has 'geohash_precision' => ( isa => Int,  is => 'ro' );

# object
has 'enabled' => ( isa => Bool,           is => 'ro' );
has 'dynamic' => ( isa => DynamicMapping, is => 'ro' );
has 'path'    => ( isa => PathMapping,    is => 'ro' );
has '_properties' => ( isa => HashRef [Str], is => 'ro' );

# nested
has 'include_in_parent' => ( isa => Bool, is => 'ro' );
has 'include_in_root'   => ( isa => Bool, is => 'ro' );

# deflation
has 'deflator' => ( isa => Maybe [CodeRef], is => 'ro', lazy_build => 1 );
has 'inflator' => ( isa => Maybe [CodeRef], is => 'ro', lazy_build => 1 );

has '_is_required' => ( isa => Bool, is => 'ro' );

#===================================
before '_process_options' => sub {
#===================================
    $_[2]->{_is_required} = 1 if delete $_[2]->{required};
};

#===================================
sub _build_deflator {
#===================================
    my $self = shift;
    my $deflator = eval { find_deflator( $self->type_constraint ) }
        or croak "No deflator found for attribute '"
        . $self->name
        . '" in class '
        . $self->associated_class->name;
    if ( $self->should_auto_deref ) {
        my $old_deflator = $deflator;
        if ( $self->type_constraint->is_a_type_of('ArrayRef') ) {
            $deflator = sub { my $seen = pop; $old_deflator->( \@_, $seen ) }
        }
        else {
            $deflator = sub { my $seen = pop; $old_deflator->( {@_}, $seen ) }
        }
    }
    return $deflator;
}

### TODO: weak refs?
#===================================
sub _build_inflator {
#===================================
    my $self = shift;
    my $inflator = eval { find_inflator( $self->type_constraint ) }
        or croak "No inflator found for attribute '"
        . $self->name
        . '" in class '
        . $self->associated_class->name;
    return $inflator;
}

1;
