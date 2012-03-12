package ESModel::Role::Doc;

use Moose::Role;
with 'ESModel::Role::ModelAttr';

use namespace::autoclean;
use ESModel::Trait::Exclude;
use MooseX::Types::Moose qw(Bool HashRef);
use ESModel::Types qw(Timestamp UID);
use Scalar::Util qw(refaddr);
use Time::HiRes();
use Carp;

#===================================
has 'uid' => (
#===================================
    isa      => UID,
    is       => 'ro',
    required => 1,
    traits   => ['ESModel::Trait::Exclude'],
    handles  => {
        index   => 'index',
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
    traits  => ['ESModel::Trait::Exclude'],
);

#===================================
has '_source' => (
#===================================
    isa     => HashRef,
    is      => 'ro',
    traits  => ['ESModel::Trait::Exclude'],
    lazy    => 1,
    builder => '_get_source',
);

#===================================
sub _get_source {
#===================================
    my $self = shift;
    $self->model->get_raw_doc( $self->uid );
}

#===================================
sub _inflate_doc {
#===================================
    my $self   = shift;
    my $source = $self->_source;
    $self->_can_inflate(0);
    $self->model->inflate_object( $self, $source );
}

#===================================
sub _new_stub {
#===================================
    my $class = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;

    my $meta = $class->meta;
    my $self = $meta->get_meta_instance->create_instance;

    my ( $uid, $model, $source ) = @params{ 'uid', 'model', '_source' };
    croak "Invalid UID"
        unless $uid && $uid->isa('ESModel::UID') && $uid->from_store;

    $meta->find_attribute_by_name('uid')->set_raw_value( $self, $uid );

    croak "Invalid model"
        unless $model && $model->does('ESModel::Role::Model');

    $meta->find_attribute_by_name('model')->set_raw_value( $self, $model );

    if ( defined $source ) {
        croak "Invalid _source" unless ref $source eq 'HASH';
        $meta->find_attribute_by_name('_source')
            ->set_raw_value( $self, $source );
    }

    $self->_can_inflate(1);
    return $self;
}

#===================================
has timestamp => (
#===================================
    traits  => ['ESModel::Trait::Field'],
    isa     => Timestamp,
    is      => 'rw',
    exclude => 0
);

no Moose::Role;

#===================================
sub touch { shift->timestamp( int( Time::HiRes::time * 1000 + 0.5 ) / 1000 ) }
#===================================

#===================================
sub save {
#===================================
    my $self = shift;
    my %args = ref $_[0] ? %{ shift() } : @_;

    $self->touch if $self->meta->timestamp_path;
    $self->model->save_doc( $self, \%args );
}

#===================================
sub delete {
#===================================
    my $self = shift;
    $self->model->delete_doc( $self, @_ );
}

1;
