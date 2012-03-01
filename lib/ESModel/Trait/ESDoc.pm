package ESModel::Trait::ESDoc;

use Moose::Role;
use MooseX::Types::Moose qw(Str);
use Class::Load qw(load_class);
use Carp;

use Moose::Role;
use Moose::Util qw(ensure_all_roles);
use ESModel::Meta::ESDoc::Method::Accessor;
use ESModel::Meta::ESDoc::Attribute;
override accessor_metaclass => sub {'ESModel::Meta::ESDoc::Method::Accessor'};

has 'uid_attr' => ( isa => Str, is => 'rw', required => 1 );
has 'uid_attr_obj' => (
    is      => 'ro',
    writer  => '_set_uid_attr_obj',
    lazy    => 1,
    builder => '_build_uid_attr_obj'
);

#===================================
around 'new' => sub {
#===================================
    my $orig = shift;
    my $attr = $orig->(@_);
    ensure_all_roles( $attr, 'ESModel::Meta::ESDoc::Attribute' );
    return $attr;
};

#===================================
sub _build_uid_attr_obj {
#===================================
    my $self = shift;
    return $self->associated_class->get_attribute( $self->uid_attr )
        || croak "Couldn't find attribute "
        . $self->uid_attr
        . " in class "
        . $self->associated_class;
}

#===================================
sub uid_method {
#===================================
    my $self = shift;
    my $name = shift;
    my $method
        = $name eq 'read'  ? 'get_read_method'
        : $name eq 'write' ? 'get_write_method'
        :                    $name;

    return $self->uid_attr_obj->$method
        || croak "No $name method exists for attribute " . $self->uid_attr;
}

1;

