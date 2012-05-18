package Elastic::Model::Namespace;

use Moose;
use MooseX::Types::Moose qw(Str HashRef);
use namespace::autoclean;

#===================================
has 'name' => (
#===================================
    is       => 'ro',
    isa      => Str,
    required => 1
);

#===================================
has 'types' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    builder => '_build_types',
    handles => {
        class_for_type => 'get',
        all_types      => 'keys'
    },
);

no Moose;

1;
