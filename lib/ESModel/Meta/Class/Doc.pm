package ESModel::Meta::Class::Doc;

use Moose::Role;
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
        unless $uid && $uid->isa('ESModel::UID') && $uid->from_store;

    $self->get_attribute('uid')->set_raw_value( $obj, $uid );

    if ( defined $source ) {
        croak "Invalid _source" unless ref $source eq 'HASH';
        $self->get_attribute('_source')->set_raw_value( $obj, $source );
    }

    $obj->_can_inflate(1);
    return $obj;
}

1;
