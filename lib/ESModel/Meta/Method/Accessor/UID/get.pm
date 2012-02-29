package ESModel::Meta::Method::Accessor::UID::get;

use strict;
use warnings;

use Moose::Role;

with 'Moose::Meta::Method::Accessor::Native::Reader' => {
    -excludes => [ qw(
            _maximum_arguments
            _inline_check_arguments
            _inline_return_value
            )
    ],
    },
    'Moose::Meta::Method::Accessor::Native::Hash';

#===================================
sub _maximum_arguments   {0}
sub _inline_return_value {'return $doc'}
#===================================

#===================================
sub _inline_check_arguments {
#===================================
    my $self   = shift;
    my $reader = $self->associated_attribute->get_read_method;
    return ( 'my $uid = $self->' . $reader . ';',
        'my $doc = $uid ? $self->model->get_doc($uid) : undef;' );
}

#around '_inline_reader_core' => sub {
#    my $orig = shift;
#    my @code = $orig->(@_);
#    print join "\n", '', @code, '', '', '';
#    @code;
#};

no Moose::Role;

1;
