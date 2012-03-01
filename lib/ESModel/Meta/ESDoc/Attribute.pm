package ESModel::Meta::ESDoc::Attribute;

use Moose::Role;

# Sets the real uid attribute
#===================================
sub set_initial_value {
#===================================
    my ($self,$instance,$value) = @_;
    $value = $value->uid if $value;
    return $self->uid_attr_obj->set_initial_value($instance,$value);
}

1;
