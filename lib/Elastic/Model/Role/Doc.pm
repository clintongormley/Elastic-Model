package Elastic::Model::Role::Doc;

use Moose::Role;

use Elastic::Model::Trait::Exclude;
use MooseX::Types::Moose qw(Bool HashRef);
use Elastic::Model::Types qw(Timestamp UID);
use Scalar::Util qw(refaddr);
use Try::Tiny;
use Time::HiRes();
use Carp;
use namespace::autoclean;

#===================================
has 'uid' => (
#===================================
    isa      => UID,
    is       => 'ro',
    required => 1,
    writer   => '_set_uid',
    traits   => ['Elastic::Model::Trait::Exclude'],
    exclude  => 1,
    handles  => {
        id      => 'id',
        type    => 'type',
        routing => 'routing'
    },
);

#===================================
has '_can_inflate' => (
#===================================
    isa     => Bool,
    is      => 'rw',
    default => 0,
    traits  => ['Elastic::Model::Trait::Exclude'],
    exclude => 1,
);

#===================================
has '_source' => (
#===================================
    isa     => HashRef,
    is      => 'ro',
    traits  => ['Elastic::Model::Trait::Exclude'],
    lazy    => 1,
    exclude => 1,
    builder => '_get_source',
    writer  => '_set_source',
    clearer => '_clear_source',
);

#===================================
sub _get_source {
#===================================
    my $self = shift;
    $self->meta->model->get_raw_doc( $self->uid );
}

#===================================
has 'timestamp' => (
#===================================
    traits  => ['Elastic::Model::Trait::Field'],
    isa     => Timestamp,
    is      => 'rw',
    exclude => 0
);

#===================================
has '_old_value' => (
#===================================
    is        => 'ro',
    isa       => HashRef,
    traits    => ['Elastic::Model::Trait::Exclude'],
    exclude   => 1,
    writer    => '_set_old_value',
    clearer   => '_clear_old_value',
    predicate => '_has_old_value'
);

no Moose::Role;

#===================================
sub has_changed {
#===================================
    my $self = shift;
    if (@_) {
        my $attr = shift;
        my $old = $self->_old_value || {};
        if ( $attr eq "1" or @_ ) {
            $old->{$attr} ||= shift unless $attr eq "1";
            $self->_set_old_value($old);
            return 1;
        }
        return exists $old->{$attr};
    }
    return $self->_has_old_value;
}

#===================================
sub old_value {
#===================================
    my $self = shift;
    my $old = $self->_old_value or return;
    if ( my $attr = shift ) {
        return $old->{$attr};
    }
    return $old;
}

#===================================
sub _inflate_doc {
#===================================
    my $self   = shift;
    my $source = $self->_source;
    $self->_can_inflate(0);
    try {
        $self->meta->model->inflate_object( $self, $source );
    }
    catch {
        $self->_can_inflate(1);
        die $_;
    };
}

#===================================
sub touch { shift->timestamp( int( Time::HiRes::time * 1000 + 0.5 ) / 1000 ) }
#===================================

#===================================
sub save {
#===================================
    my $self = shift;
    my %args = ref $_[0] ? %{ shift() } : @_;

    if ( $self->has_changed || !$self->uid->from_store ) {
        $self->touch;
        $self->meta->model->save_doc( $self, \%args );
    }
    $self;
}

#===================================
sub delete {
#===================================
    my $self = shift;
    $self->meta->model->delete_doc( $self, @_ );
}

1;
