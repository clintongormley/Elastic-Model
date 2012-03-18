package Elastic::Model::Role::Doc;

use Moose::Role;

use Elastic::Model::Trait::Exclude;
use MooseX::Types::Moose qw(Bool HashRef);
use Elastic::Model::Types qw(Timestamp UID);
use Scalar::Util qw(refaddr);
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
);

#===================================
has '_source' => (
#===================================
    isa     => HashRef,
    is      => 'ro',
    traits  => ['Elastic::Model::Trait::Exclude'],
    lazy    => 1,
    builder => '_get_source',
    writer  => '_overwrite_source',
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

no Moose::Role;

#===================================
#===================================
sub _inflate_doc {
#===================================
    my $self   = shift;
    my $source = $self->_source;
    $self->_clear_source;
    $self->_can_inflate(0);
    try {
        $self->meta->model->inflate_object( $self, $source );
    }
    catch {
        $self->_overwrite_source($source);
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

    $self->meta->model->save_doc( $self, \%args );
        $self->touch;
}

#===================================
sub delete {
#===================================
    my $self = shift;
    $self->meta->model->delete_doc( $self, @_ );
}

1;
