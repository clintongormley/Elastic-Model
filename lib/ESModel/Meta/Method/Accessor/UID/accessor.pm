package ESModel::Meta::Method::Accessor::UID::accessor;

use strict;
use warnings;

use Moose::Role;

with 'ESModel::Meta::Method::Accessor::UID::set' => {
    -excludes => [ qw(
            _minimum_arguments
            _maximum_arguments
            _generate_method
            _inline_process_arguments
            )
    ]
};

with 'ESModel::Meta::Method::Accessor::UID::get' => {
    -excludes => [ qw(
            _minimum_arguments
            _maximum_arguments
            _inline_check_arguments
            _generate_method
            _return_value
            _inline_return_value
            )
    ]
};

#===================================
sub _minimum_arguments {0}
sub _maximum_arguments {1}
#===================================

#===================================
sub _generate_method {
#===================================
    my $self = shift;

    my $inv         = '$self';
    my $slot_access = $self->_get_value($inv);
    my $reader      = $self->associated_attribute->get_read_method;

    return (
        'sub {',
        'my ' . $inv . ' = shift;',

        # set
        'if (@_) {',
        $self->_inline_writer_core( $inv, $slot_access ),
        '}',

        # get
        'else {',
        'my $uid = $self->' . $reader . ';',
        'return $uid ? $self->model->get_doc($uid) : undef;',
        '}',
        '}'
    );
}

#around '_generate_method' => sub {
#    my $orig = shift;
#    my @code = $orig->(@_);
#    print join "\n\n", '', @code, '', '', '';
#    @code;
#};

no Moose::Role;

1;
