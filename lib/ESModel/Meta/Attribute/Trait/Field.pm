package ESModel::Meta::Attribute::Trait::Field;

use Moose::Role;
use ESModel::Type::Deflator qw(find_deflator find_inflator);
use ESModel::Types qw(
    FieldType IndexMapping TermVectorMapping MultiFields
    StoreMapping DynamicMapping PathMapping
);

use namespace::autoclean;

has 'type' => ( isa => FieldType, is => 'ro' );
has 'mapping' => ( isa => 'HashRef[Str]', is => 'ro' );
has 'exclude' => ( isa => 'Bool',         is => 'ro' );

has 'include_in_all' => ( isa => 'Bool', is => 'ro' );

has 'index' => ( isa => IndexMapping, is => 'ro' );
has 'store' => ( isa => StoreMapping, is => 'ro', coerce => 1 );
has 'multi' => ( isa => MultiFields,  is => 'ro' );

has 'index_name' => ( isa => 'Str', is => 'ro' );
has 'boost'      => ( isa => 'Num', is => 'ro' );
has 'null_value' => ( isa => 'Str', is => 'ro' );

# strings
has 'analyzer'                     => ( isa => 'Str',  is => 'ro' );
has 'index_analyzer'               => ( isa => 'Str',  is => 'ro' );
has 'search_analyzer'              => ( isa => 'Str',  is => 'ro' );
has 'omit_norms'                   => ( isa => 'Bool', is => 'ro' );
has 'omit_term_freq_and_positions' => ( isa => 'Bool', is => 'ro' );
has 'term_vector' => ( isa => TermVectorMapping, is => 'ro' );

# dates
has 'format'         => ( isa => 'Str', is => 'ro' );
has 'precision_step' => ( isa => 'Int', is => 'ro' );

# geo-point
has 'geohash'           => ( isa => 'Bool', is => 'ro' );
has 'lat_lon'           => ( isa => 'Bool', is => 'ro' );
has 'geohash_precision' => ( isa => 'Int',  is => 'ro' );

# object
has 'enabled' => ( isa => 'Bool', is => 'ro' );
has 'dynamic' => ( isa => DynamicMapping, is => 'ro' );
has 'path'    => ( isa => PathMapping,    is => 'ro' );
has '_properties' => ( isa => 'HashRef[Str]', is => 'ro' );

# nested
has 'include_in_parent' => ( isa => 'Bool', is => 'ro' );
has 'include_in_root'   => ( isa => 'Bool', is => 'ro' );

# Disable raw get/set
has 'safe_access' => ( isa => 'Bool',           is => 'ro', default    => 0 );
has 'deflator'    => ( isa => 'Maybe[CodeRef]', is => 'ro', lazy_build => 1 );
has 'inflator'    => ( isa => 'Maybe[CodeRef]', is => 'ro', lazy_build => 1 );

#===================================
sub _build_deflator { find_deflator(@_) }
sub _build_inflator { find_inflator(@_) }
#===================================

1;
