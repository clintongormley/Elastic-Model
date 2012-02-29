package ESModel::Trait::UID;

use Moose::Role;
with 'Moose::Meta::Attribute::Native::Trait' =>
    { -excludes => ['_native_accessor_class_for'] };

use ESModel::Types qw(UID ESDoc ESTypeConstraint);
use Class::Load qw(load_class);

#===================================
has 'doc_isa' => (
#===================================
    isa     => ESTypeConstraint,
    is      => 'rw',
    coerce  => 1,
    default => sub {ESDoc},
);

# TODO: Should this only accept UIDs that are from_store?
#===================================
sub _helper_type {UID}
#===================================

#===================================
before '_process_options' => sub {
#===================================
    my ( $self, $name, $options ) = @_;
    $options->{coerce} = 1 unless exists $options->{coerce};
};

#===================================
override '_eval_environment' => sub {
#===================================
    my $self = shift;
    my $env  = super();

    my $tc = $self->doc_isa;

    $env->{'$doc_tc'} = \( $tc->_compiled_type_constraint )
        unless $tc->can_be_inlined;
    $env->{'$doc_message'}
        = \( $tc->has_message ? $tc->message : $tc->_default_message );

    $env = { %$env, %{ $tc->inline_environment } };

    return $env;
};

#===================================
sub _native_accessor_class_for {
#===================================
    my ( $self, $suffix ) = @_;
    my $role = 'ESModel::Meta::Method::Accessor::UID::' . $suffix;
    load_class($role);
    return Moose::Meta::Class->create_anon_class(
        superclasses =>
            [ $self->accessor_metaclass, $self->delegation_metaclass ],
        roles => [$role],
        cache => 1,
    )->name;
}

no Moose::Role;

1;

