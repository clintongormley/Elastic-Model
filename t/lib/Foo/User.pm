package Foo::User;

use Moose;
use Elastic::Doc;
use MooseX::Types::Moose qw(Str);
use namespace::autoclean;

#===================================
has 'name' => (
#===================================
    is  => 'rw',
    isa => Str,
);

#===================================
has 'email' => (
#===================================
    is  => 'ro',
    isa => Str,
);

no Moose;

1;
