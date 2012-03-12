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
around 'BUILDARGS' => sub {
#===================================
    my $orig   = shift;
    my $class  = $_[0];
    my $params = $orig->(@_);

    my $uid = $params->{uid};
    if ( $uid and $uid->from_store ) {
        delete $params->{_source} unless $params->{_source};
        $params->{_can_inflate} = 1;
    }
    else {
        $params->{_can_inflate} = 0;
        my $required = $class->meta->required_attrs;
        for my $name ( keys %$required ) {
            croak "Attribute ($name) is required"
                unless defined $params->{ $required->{$name} };
        }
    }
    return $params;
};

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
    $self->model->save_doc($self);
}

#===================================
sub delete {
#===================================
    my $self   = shift;
    my %args   = ref $_[0] ? %{ shift() } : @_;
    my $result = $self->model->store->delete_doc( $self->uid, \%args );
    $self->uid->update_from_store($result);
    $self;
}

1;
