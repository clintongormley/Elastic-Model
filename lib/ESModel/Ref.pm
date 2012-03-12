package ESModel::Ref;

use Moose;
with 'ESModel::Role::ModelAttr';
use ESModel::Types qw(UID);

#===================================
has 'uid' => (
#===================================
    is       => 'ro',
    isa      => UID,
    required => 1,
);

#===================================
sub vivify {
#===================================
    my $self = shift;
    $self->model->get_doc( $self->uid );
}

1;
