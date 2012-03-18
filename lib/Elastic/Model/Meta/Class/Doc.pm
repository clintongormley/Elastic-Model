package Elastic::Model::Meta::Class::Doc;

use Moose::Role;
with 'Elastic::Model::Meta::Class';

use Carp;
use namespace::autoclean;

#===================================
sub new_stub {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;

    my $obj = $self->get_meta_instance->create_instance;

    my ( $uid, $source ) = @params{ 'uid', '_source' };
    croak "Invalid UID"
        unless $uid && $uid->isa('Elastic::Model::UID') && $uid->from_store;
    $obj->_set_uid($uid);

    if ( defined $source ) {
        croak "Invalid _source" unless ref $source eq 'HASH';
        $obj->_overwrite_source($source);
    }

    $obj->_can_inflate(1);
    return $obj;
}

1;
