package ESModel::Scope;

use Moose;
use namespace::autoclean;
use MooseX::Types::Moose qw(:all);

#===================================
has '_objects' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

#===================================
sub get_object {
#===================================
    my $self = shift;
    my $uid  = shift;
    my $existing = $self->_objects->{ $uid->as_string } or return;
    return if $uid->version && $uid->version > $existing->uid->version;
    return $existing;
}

#===================================
sub store_object {
#===================================
    my $self   = shift;
    my $object = shift;
    my $uid    = $object->uid;
    if ( my $existing = $self->_objects->{$uid->as_string} ) {
        return $existing if $existing->uid->version >= $uid->version;
        $existing->_overwrite_source( $object->_source );
        $existing->_can_inflate(1);
        $existing->uid->update_from_store( $uid->as_version_params );
        return $existing;
    }
    $self->_objects->{ $uid->as_string } = $object;
}

1;
