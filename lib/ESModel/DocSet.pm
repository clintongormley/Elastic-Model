package ESModel::DocSet;

use Moose;
use Carp;
use ESModel::Types qw(IndexNames TypeNames);
use MooseX::Attribute::ChainedClone();

has 'model' => (
    does     => 'ESModel::Role::Model',
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

has 'index' => (
    traits  => ['ChainedClone'],
    isa     => IndexNames,
    is      => 'rw',
    lazy    => 1,
    builder => '_build_index_names',
    coerce  => 1,
);

has 'type' => (
    traits  => ['ChainedClone'],
    is      => 'rw',
    isa     => TypeNames,
    default => sub { [] },
    coerce  => 1,
);

no Moose;

#===================================
sub _build_index_names { [ shift->model->meta->all_indices ] }
#===================================

#===================================
sub _single {
#===================================
    my ( $self,  $name )   = @_;
    my ( $first, $second ) = @{ $self->$name };
    if ( defined $second ) {
        my ($method) = ( caller(1) )[3];
        $method =~ s/.+:://;
        croak "$method() can only be called on a DocSet with a single $name";
    }
    return $first;
}

#===================================
sub get {
#===================================
    my $self = shift;
    my %params = ref $_[0] ? %{ shift() } : @_ == 1 ? ( id => shift() ) : @_;
    $params{id} or croak "No 'id' passed to get()";

    my $result = $self->model->es->get(
        index  => $self->_single('index'),
        type   => $self->_single('type') || '_all',
        fields => [ '_routing', '_parent', '_source' ],
        %params
    ) or return;
    return $self->_instantiate_doc($result);
}

#===================================
sub _instantiate_doc {
#===================================
    my ( $self, $result ) = @_;
    my ( $index, $type, $source ) = @{$result}{qw(_index _type _source )};

    my $model  = $self->model;
    my $fields = $result->{fields} || {};
    my $class  = $model->index($index)->class_for_type($type);
    my $data   = $class->inflate( $result->{_source} );

    return $class->new(
        model             => $model,
        index             => $index,
        type              => $type,
        id                => $result->{_id},
        version           => $result->{_version},
        is_from_datastore => 1,
        defined $fields->{_parent}  ? ( parent => $fields->{_parent} )  : (),
        defined $fields->{_routing} ? ( parent => $fields->{_routing} ) : (),
        %$data
    );
}

#===================================
sub new_doc {
#===================================
    my $self   = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    my $index  = $self->_single('index');
    my $type   = $self->_single('type');
    croak "Cannot create a new doc on a DocSet with no type"
        unless defined $type;

    my $class = $self->model->index($index)->class_for_type($type);
    return $class->new(
        model => $self->model,
        index => $index,
        type  => $type,
        %params
    );
}

1;
