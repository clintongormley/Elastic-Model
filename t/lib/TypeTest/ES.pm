package TypeTest::ES;

use Elastic::Doc;
use Elastic::Model::Types qw(GeoPoint Binary );

# UID and Timestamp tested in Objects

#===================================
has 'geopoint_attr' => (
#===================================
    is  => 'ro',
    isa => GeoPoint,
);

#===================================
has 'binary_attr' => (
#===================================
    is  => 'ro',
    isa => Binary,
);

no Elastic::Doc;

1;
