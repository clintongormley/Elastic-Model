package ESModel::Meta::Method::Accessor::UID::clear;

use strict;
use warnings;

use Moose::Role;

with 'Moose::Meta::Method::Accessor::Native::Writer' => {
    -excludes => [ qw(
            _inline_set_new_value
            _inline_copy_native_value
            _inline_optimized_set_new_value
            _inline_tc_code
            _return_value
            )
    ]
};

#===================================
sub _potential_value          {'undef'}
sub _inline_tc_code           { }
sub _inline_copy_native_value { }
sub _inline_set_new_value     { shift->_inline_optimized_set_new_value(@_) }
sub _return_value             {''}
#===================================

#===================================
sub _inline_optimized_set_new_value {
#===================================
    my $self = shift;
    my ( $inv, $new, $slot_access ) = @_;

    return "delete $slot_access;";
}

#around '_inline_writer_core' => sub {
#    my $orig = shift;
#    my @code = $orig->(@_);
#    print join "\n\n", 'CLEAR:', @code, '', '', '';
#    @code;
#};

no Moose::Role;

1;
