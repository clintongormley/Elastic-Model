package Elastic::Model::Scope;

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
has 'parent' => (
#===================================
    is  => 'ro',
    isa => 'Elastic::Model::Scope',
);
sub get_object {
#===================================
    my ( $self, $domain, $uid ) = @_;
    my $existing = $self->_objects->{$domain}{ $uid->cache_key } or return;
    return if $uid->version && $uid->version > $existing->uid->version;
    return $existing;
}

#===================================
sub store_object {
#===================================
    my ( $self, $domain, $object ) = @_;
    my $uid = $object->uid;
    if ( my $existing = $self->_objects->{$domain}{ $uid->cache_key } ) {
        return $existing if $existing->uid->version >= $uid->version;
        $existing->_overwrite_source( $object->_source );
        $existing->_can_inflate(1);
        $existing->uid->update_from_uid($uid);
        return $existing;
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
