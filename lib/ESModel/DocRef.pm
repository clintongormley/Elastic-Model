package ESModel::DocRef;

use Moose;
use ESModel::Types qw(UID);
use namespace::autoclean;

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
