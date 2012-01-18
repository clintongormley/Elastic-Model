package ESModel::Meta::Class::Model;

use Moose::Role;
use List::Util ();
use Carp;

my %attr = (
    index       => 'indices',
    type        => 'types',
    char_filter => 'char_filters',
    analyzer    => 'analyzers',
    filter      => 'filters',
    tokenizer   => 'tokenizers',
);

while ( my ( $singular, $plural ) = each %attr ) {
    has $plural => (
        is      => 'ro',
        traits  => ['Hash'],
        isa     => 'HashRef',
        default => sub { {} },
        handles => {
            "get_$singular"      => 'get',
            "add_${singular}"    => 'set',
            "remove_${singular}" => 'delete',
        }
    );
}

1;
