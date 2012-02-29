package ESModel::Meta::Method::Accessor::UID::has;

use strict;
use warnings;

use Moose::Role;

with 'Moose::Meta::Method::Accessor::Native::Reader';

#===================================
sub _return_value {
#===================================
    my $self = shift;
    my ($slot_access) = shift;
    return 'exists ' . $slot_access;
}

#around '_inline_reader_core' => sub {
#    my $orig = shift;
#    my @code = $orig->(@_);
#    print join "\n", 'HAS:', @code, '', '', '';
#    @code;
#};

no Moose::Role;

1;
