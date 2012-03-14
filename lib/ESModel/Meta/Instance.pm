package ESModel::Meta::Instance;
use Moose::Role;
use Scalar::Util qw(blessed);
use namespace::autoclean;

#===================================
around [
    'get_slot_value',    'set_slot_value',
    'deinitialize_slot', 'is_slot_initialized'
    ] => sub {
#===================================
    my ( $next, $self, $instance, $slot, @args ) = @_;
    my $attr = $self->associated_metaclass->find_attribute_by_name($slot);
    $attr->exclude
        || $instance->_can_inflate && $instance->_inflate_doc;
    $self->$next( $instance, $slot, @args );
    };

#===================================
around [
    'inline_get_slot_value',    'inline_set_slot_value',
    'inline_deinitialize_slot', 'inline_is_slot_initialized'
    ] => sub {
#===================================
    my ( $next, $self, $instance_expr, $slot, @args ) = @_;
    my $expr = $self->$next( $instance_expr, $slot, @args );
    my $attr = $self->associated_metaclass->find_attribute_by_name($slot);
    return $expr if $attr->can('exclude') && $attr->exclude;

    return
          'do {'
        . $instance_expr
        . '->_inflate_doc if '
        . $instance_expr
        . '->_can_inflate;'
        . $expr . '}';
    };

#===================================
sub inline_get_is_lvalue {0}
#===================================

1;
