package Elastic::Model::Meta::Class::Doc;

use Moose::Role;

use MooseX::Types::Moose qw(HashRef);
use Carp;
use namespace::autoclean;
use Variable::Magic qw(cast wizard);

my $wiz = wizard( map { $_ => \&_inflate } qw(fetch store exists delete) );
my %exclude = map { $_ => 1 } qw(uid _can_inflate _source);

#===================================
has 'mapping' => (
#===================================
    isa     => HashRef,
    is      => 'rw',
    default => sub { {} }
);

#===================================
sub new_stub {
#===================================
    my ( $self, $uid, $source ) = @_;

    my $obj = $self->get_meta_instance->create_instance;

    croak "Invalid UID"
        unless $uid && $uid->isa('Elastic::Model::UID') && $uid->from_store;

    $obj->_set_uid($uid);
    $obj->_set_source($source) if $source;
    $obj->_can_inflate(1);
    cast %$obj, $wiz;
    return $obj;
}

#===================================
sub _inflate {
#===================================
    my ( $obj, undef, $key ) = @_;
    return if $exclude{ $key || '' };
    $obj->_inflate_doc if $obj->{_can_inflate};
}

1;

__END__

# ABSTRACT: A meta-class for Docs

=head1 DESCRIPTION

Extends the meta-class for classes which do L<Elastic::Model::Role::Doc>.
You shouldn't need to use anything from this class directly.

=head1 ATTRIBUTES

=head2 mapping

    $mapping = $meta->mapping($mapping);

Used to store custom mapping config for a class.  Use the
L<Elastic::Doc/"has_mapping">  sugar instead of calling this method directly.

=head1 METHODS

=head2 new_stub()

    $stub_doc = $meta->new_stub($uid);
    $stub_doc = $meta->new_stub($uid, $source);

Creates a stub instance of the class, which auto-inflates when any accessor
is called.  If the C<$source> param is defined, then it is used to inflate
the attributes of the instance, otherwise the attributes are fetched from
ElasticSearch when an attribute is accessed.

