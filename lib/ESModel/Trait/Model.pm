package ESModel::Trait::Model;

use Moose::Role;

#===================================
has 'model' => (
#===================================
    traits   => ['ESModel::Trait::Exclude'],
    does     => 'ESModel::Role::Model',
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

1;
