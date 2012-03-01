package ESModel::Meta::ESDoc::Method::Accessor;

use Carp;
use Try::Tiny;

use base 'Moose::Meta::Method::Accessor';

#===================================
sub _generate_accessor_method_inline {
#===================================
    my $self   = shift;
    my $attr   = $self->associated_attribute;
    my $reader = $attr->uid_method('read');
    my $writer = $attr->uid_method('write');
    return try {
        $self->_compile_code( [
                'sub {',
                'my $self = shift;',
                'if (@_) {',
                'my $uid = $_[0] ? $_[0]->uid : undef;',
                '$self->' . $writer . '($_[0] ? $_[0]->uid : undef);',
                'return $_[0];',
                '}',
                'my $uid = $self->' . $reader . ' or return;',
                '$self->model->get_doc($uid)',
                '}',
            ]
        );
    }
    catch {
        confess "Could not generate inline accessor because : $_";
    };
}

#===================================
sub _generate_writer_method_inline {
#===================================
    my $self   = shift;
    my $writer = $$self->associated_attribute->uid_method('write');
    return try {
        $self->_compile_code( [
                'sub {',
                'my $self = shift;',
                'my $uid = $_[0] ? $_[0]->uid : undef;',
                '$self->' . $writer . '($_[0] ? $_[0]->uid : undef);',
                'return $_[0];',
                '}',
            ]
        );
    }
    catch {
        confess "Could not generate inline writer because : $_";
    };
}

#===================================
sub _generate_reader_method_inline {
#===================================
    my $self   = shift;
    my $reader = $$self->associated_attribute->uid_method('read');
    return try {
        $self->_compile_code( [
                'sub {',
                'my $self = shift;',
                'my $uid = $self->' . $reader . ' or return;',
                '$self->model->get_doc($uid)', '}',
            ]
        );
    }
    catch {
        confess "Could not generate inline reader because : $_";
    };
}

#===================================
sub _generate_predicate_method_inline {
#===================================
    my $self      = shift;
    my $predicate = $self->associated_attribute->uid_method('predicate');
    return try {
        $self->_compile_code( [ 'sub {', 'shift->' . $predicate, '}' ] );
    }
    catch {
        confess "Could not generate inline predicate because : $_";
    };
}

#===================================
sub _generate_clearer_method_inline {
#===================================
    my $self    = shift;
    my $clearer = $self->associated_attribute->uid_method('clearer');
    return try {
        $self->_compile_code( [ 'sub {', 'shift->' . $clearer, '}' ] );
    }
    catch {
        confess "Could not generate inline clearer because : $_";
    };
}

1;

