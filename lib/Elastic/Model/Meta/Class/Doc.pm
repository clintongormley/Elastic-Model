package Elastic::Model::Meta::Class::Doc;

use Moose::Role;
with 'Elastic::Model::Meta::Class';

use MooseX::Types::Moose qw(HashRef);
use Carp;
use namespace::autoclean;

#===================================
has 'type_mapping' => (
#===================================
    isa     => HashRef,
    is      => 'rw',
    default => sub { {} }
);

#===================================
sub new_stub {
#===================================
    my ( $self, $uid, $source ) = @_;

    my $obj = $self->get_meta_instance->create_instance;

    croak "Invalid UID"
        unless $uid && $uid->isa('Elastic::Model::UID') && $uid->from_store;

    $obj->_set_uid($uid);
    $obj->_set_source($source) if $source;
    $obj->_can_inflate(1);
    return $obj;
}

1;
