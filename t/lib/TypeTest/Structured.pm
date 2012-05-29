package TypeTest::Structured;

use Elastic::Doc;
use MooseX::Types::Moose qw(:all);
use MooseX::Types::Structured qw(:all);

#===================================
has 'tuple_attr' => (
#===================================
    is  => 'ro',
    isa => Tuple [ Str, Int ],
);

#===================================
has 'dict_attr' => (
#===================================
    is  => 'ro',
    isa => Dict [ str => Str, int => Int ]
);

#===================================
has 'map_attr' => (
#===================================
    is  => 'ro',
    isa => Map [ Int, Str ],
);

#===================================
has 'optional_attr' => (
#===================================
    is  => 'ro',
    isa => Optional [Int],
);

#===================================
has 'combo_attr' => (
#===================================
    is  => 'ro',
    isa => Dict [
        str  => Str,
        dict => Dict [ Int, Optional [Str] ],
        map  => Optional [ Map [ Str, Int ] ]
    ]
);

no Elastic::Doc;

1;

