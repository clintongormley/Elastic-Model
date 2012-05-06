package Elastic::Model::Meta::Class;

use Moose::Role;
use MooseX::Types::Moose qw(Str);
use namespace::autoclean;

#===================================
has 'model' => (
#===================================
    traits   => ['Elastic::Model::Trait::Exclude'],
    does     => 'Elastic::Model::Role::Model',
    is       => 'ro',
    writer   => '_set_model',
    weak_ref => 1,
);

#===================================
has 'original_class' => (
#===================================
    is     => 'ro',
    isa    => Str,
    writer => '_set_original_class',
);

1;

__END__

# ABSTRACT: Extends wrapped classes

=head1 DESCRIPTION

A meta-class which is applied to wrapped classes. All classes used in a model
are wrapped to include an instance of the model, to avoid having to pass
the C<$model> around from class to class.

=head1 ATTRIBUTES

=head2 model

    $model = $wrapped_class->meta->model()

Returns a singleton of the model instance to which the wrapped class belongs.

=head2 original_class

    $class = $wrapped_class->meta->original_class()

Returns the original name of the wrapped class.

=cut


