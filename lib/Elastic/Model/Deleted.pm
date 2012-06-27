package Elastic::Model::Deleted;

use Moose;
use strict;
use warnings;
use Carp;
use namespace::autoclean;

#===================================
has 'uid' => (
#===================================
    is       => 'ro',
    isa      => 'Elastic::Model::UID',
    required => 1,
);

#===================================
sub _can_inflate     {0}
sub _inflate_doc     { }
sub has_been_deleted {1}
#===================================

our $AUTOLOAD;

#===================================
sub AUTOLOAD {
#===================================
    my $self = shift;
    my $uid  = $self->uid;
    croak
        sprintf(
        "Object type (%s) with ID (%s) in index (%s) has been deleted",
        $uid->type, $uid->id, $uid->index );
}

__PACKAGE__->meta->make_immutable;

1;
