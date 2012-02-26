package ESModel::Doc::Result;

use Moose;
with 'ESModel::Trait::Model';
use MooseX::Types::Moose qw(:all);

has 'result' => (
    isa      => HashRef,
    is       => 'ro',
    required => 1,
);

has 'metadata' => (
    isa     => 'ESModel::Doc::Metadata',
    is      => 'ro',
    lazy    => 1,
    builder => '_build_metadata',
    handles => { map { $_ => $_ } qw(index type id parent) }
);

no Moose;

#===================================
sub _build_metadata {
#===================================
    my $self = shift;
    ESModel::Doc::Metadata->new_from_datastore( $self->result );
}

#===================================
sub object {
#===================================
    my $self = shift;
    $self->model->inflate_doc( $self->result );
}

#===================================
sub fields        { shift->result->{fields}        ||= {} }
sub script_fields { shift->result->{script_fields} ||= {} }
sub highlight     { shift->result->{highlight}     ||= {} }
sub score         { shift->result->{_score} }
#===================================
1;
