package ESModel::Meta::Method::Accessor::UID::set;

use strict;
use warnings;

use Moose::Role;

with 'Moose::Meta::Method::Accessor::Native::Writer' => {
    -excludes => [ qw(
            _minimum_arguments
            _maximum_arguments
            _inline_tc_code
            _inline_check_constraint
            _inline_set_new_value
            _inline_optimized_set_new_value
            _inline_return_value
            )
    ]
};

#===================================
sub _minimum_arguments    {1}
sub _maximum_arguments    {1}
sub _inline_return_value  {'return $doc'}
sub _potential_value      {'$_[0]'}
sub _inline_set_new_value { shift->_inline_optimized_set_new_value(@_) }
#===================================

#===================================
around '_inline_copy_native_value' => sub {
#===================================
    my $orig = shift;
    return (
        $orig->(@_),
        'my $doc = $potential;',
        '$potential = $doc->uid if $doc;'
    );
};

#===================================
sub _inline_optimized_set_new_value {
#===================================
    my $self = shift;
    my ( $inv, $new, $slot_access ) = @_;
    my $writer = $self->associated_attribute->get_write_method;
    return $inv . '->' . $writer . '($potential);';
}

#===================================
sub _inline_tc_code {
#===================================
    my $self      = shift;
    my $value     = '$doc';
    my $tc_obj    = $self->associated_attribute->doc_isa;
    my $attr_name = 'foo';
    my $tc        = '$doc_tc';
    my $message   = '$doc_message';
    if ( $tc_obj->can_be_inlined ) {
        return (
            'if (! (' . $tc_obj->_inline_check($value) . ')) {',
            $self->_inline_throw_error(
                '"Attribute ('
                    . $attr_name
                    . ') does not pass the type '
                    . 'constraint because: " . '
                    . 'do { local $_ = '
                    . $value . '; '
                    . $message . '->('
                    . $value . ')' . '}',
                'data => ' . $value
                )
                . ';',
            '}',
        );
    }
    else {
        return (
            'if (!' . $tc . '->(' . $value . ')) {',
            $self->_inline_throw_error(
                '"Attribute ('
                    . $attr_name
                    . ') does not pass the type '
                    . 'constraint because: " . '
                    . 'do { local $_ = '
                    . $value . '; '
                    . $message . '->('
                    . $value . ')' . '}',
                'data => ' . $value
                )
                . ';',
            '}',
        );
    }

}

#around '_inline_writer_core' => sub {
#    my $orig = shift;
#    my @code = $orig->(@_);
#    print join "\n\n", '', @code, '', '', '';
#    @code;
#};

no Moose::Role;

1;
