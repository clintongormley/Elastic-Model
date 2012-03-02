package ESModel::Doc::Result;

use Moose;
with 'ESModel::Role::ModelAttr';
use ESModel::Types qw(UID);
use MooseX::Types::Moose qw(:all);

has 'result' => (
    isa      => HashRef,
    is       => 'ro',
    required => 1,
);

has 'uid' => (
    isa     => UID,
    is      => 'ro',
    lazy    => 1,
    builder => '_build_uid',
    handles => { map { $_ => $_ } qw(index type id routing) }
);

no Moose;

#===================================
sub _build_uid {
#===================================
    my $self = shift;
    ESModel::Doc::UID->new_from_store( $self->result );
}

#===================================
sub object {
#===================================
    my $self   = shift;
    my $uid    = $self->uid;
    my $result = $self->result;
    if ( $result->{_source} ) {
        return $self->model->inflate_doc( $uid, $result->{_source} );
    }
    $self->model->get_doc($uid);
}

#===================================
sub source { shift->result->{_source} }
sub score  { shift->result->{_score} }
#===================================

#===================================
sub fields        { shift->result->{fields}        ||= {} }
sub script_fields { shift->result->{script_fields} ||= {} }
sub highlight     { shift->result->{highlight}     ||= {} }
#===================================

1;
