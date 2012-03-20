package Elastic::Model::Scope;

use Moose;
use namespace::autoclean;
use MooseX::Types::Moose qw(:all);
use Scalar::Util qw(refaddr);

#===================================
has '_objects' => (
#===================================
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

#===================================
has 'parent' => (
#===================================
    is  => 'ro',
    isa => 'Elastic::Model::Scope',
);

# if the object exists in the current scope
#   return the object if its version is the same or higher
#   otherwise return undef
# otherwise, look for the same object in a parent scope
# and, if found, create a clone in the current scope

#===================================
sub get_object {
#===================================
    my ( $self, $domain, $uid ) = @_;
    my $existing = $self->_objects->{$domain}{ $uid->cache_key };

    if ($existing) {
        return $uid->version && $uid->version > $existing->uid->version
            ? undef
            : $existing;
    }

    my $parent = $self->parent or return undef;
    $existing = $parent->get_object( $domain, $uid ) or return undef;

    my $new = $existing->meta->new_stub( $uid, $existing->_source );
    return $self->store_object( $domain, $new );
}

# if the object exists in the current scope
#   return the same object if the version is the same or higher
#   if the existing object has not already been looked at
#     then update it with current details, and return it
#     else move the old version to 'old'
# store the new version in current scope

#===================================
sub store_object {
#===================================
    my ( $self, $domain, $object ) = @_;
    my $uid     = $object->uid;
    my $objects = $self->_objects;

    if ( my $existing = $objects->{$domain}{ $uid->cache_key } ) {
        return $existing if $existing->uid->version >= $uid->version;

        if ( $existing->_can_inflate ) {
            $existing->_set_source( $object->_source );
            $existing->uid->update_from_uid($uid);
            return $existing;
        }

        $objects->{old}{ $uid->cache_key . refaddr $existing} = $existing;
    }

    $self->_objects->{$domain}{ $uid->cache_key } = $object;
}

#===================================
sub DEMOLISH {
#===================================
    my $self = shift;
    $self->meta->model->detach_scope($self);
}

1;
