package ESModel::Meta::Instance;
use Moose::Role;
use Scalar::Util qw(blessed);
use namespace::autoclean;

#===================================
around 'get_slot_value', => sub {
#===================================
    my ( $next, $self, $instance, $slot, @args ) = @_;

    my $attr = $self->associated_metaclass->find_attribute_by_name($slot);
    $attr->exclude
        ||

        # $instance->can('_can_inflate') &&
        $instance->_can_inflate
        && $instance->_inflate_doc;

    my $val = $self->$next( $instance, $slot, @args );
    return $val unless blessed $val and $val->isa('ESModel::DocRef');
    $val->vivify;
};

#===================================
around [ 'set_slot_value', 'deinitialize_slot', 'is_slot_initialized' ] =>
    sub {
#===================================
    my ( $next, $self, $instance, $slot, @args ) = @_;
    my $attr = $self->associated_metaclass->find_attribute_by_name($slot);
    $attr->exclude
        ||

        # $instance->can('_can_inflate') &&
        $instance->_can_inflate
        && $instance->_inflate_doc;
    $self->$next( $instance, $slot, @args );
    };

#===================================
around 'inline_get_slot_value' => sub {
#===================================
    my ( $next, $self, $instance_expr, $slot, @args ) = @_;
    my $expr = $self->$next( $instance_expr, $slot, @args );

    my $meta = $self->associated_metaclass;
    my $attr = $self->associated_metaclass->find_attribute_by_name($slot);
    return $expr if $attr->exclude;

    return 'do {' . $instance_expr . '->_inflate_doc if '

        #        . $instance_expr
        #        . '->can("_can_inflate") && '
        . $instance_expr
        . '->_can_inflate;'
        . 'my $val = '
        . $expr
        . '; Scalar::Util::blessed($val) && $val->isa("ESModel::DocRef")'
        . ' ? $val->vivify : $val}';
};

#===================================
around [
    'inline_set_slot_value', 'inline_deinitialize_slot',
    'inline_is_slot_initialized'
    ] => sub {
#===================================
    my ( $next, $self, $instance_expr, $slot, @args ) = @_;
    my $expr = $self->$next( $instance_expr, $slot, @args );
    my $attr = $self->associated_metaclass->find_attribute_by_name($slot);
    return $expr if $attr->can('exclude') && $attr->exclude;

    return 'do {' . $instance_expr . '->_inflate_doc if '

        #        . $instance_expr
        #        . '->can("_can_inflate") && '
        . $instance_expr . '->_can_inflate;' . $expr . '}';
    };

#===================================
sub inline_get_is_lvalue {0}
#===================================

1;
