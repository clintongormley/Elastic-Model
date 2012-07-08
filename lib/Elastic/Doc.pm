package Elastic::Doc;

use Moose();
use Moose::Exporter;
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    base_class_roles => ['Elastic::Model::Role::Doc'],
    with_meta        => ['has_mapping'],
    class_metaroles  => {
        class     => ['Elastic::Model::Meta::Class::Doc'],
        attribute => ['Elastic::Model::Trait::Field'],
    },
    also => 'Moose',
);

#===================================
sub has_mapping { shift->mapping(@_) }
#===================================

1;

__END__

# ABSTRACT: Adds Elastic::Model functionality to your object classes

=head1 SYNOPSIS

=head2 Simple class definition

    package MyApp::User;

    use Elastic::Doc;

    has 'name' => (
        is  => 'rw',
        isa => 'Str'
    );

    no Elastic::Doc;


=head2 More complex class definition

    package MyApp::User;

    use Elastic::Doc;

    has_mapping {
        _ttl => {                   # delete documents/object after 2 hours
            enabled => 1,
            default => '2h'
        }
    };

    has 'user' => (
        is  => 'ro',
        isa => 'MyApp::User'
    );

    has 'title' => (
        is       => 'rw',
        isa      => 'Str',
        analyzer => 'edge_ngrams'   # use custom analyzer
    );

    has 'body' => (
        is       => 'rw',
        isa      => 'Str',
        analyzer => 'english',      # use builtin analyzer
    );

    has 'created' => (
        is       => 'ro',
        isa      => 'DateTime',
        default  => sub { DateTime->new }
    );

    has 'tag' => (
        is      => 'ro',
        isa     => 'Str',
        index   => 'not_analyzed'   # index exact value
    );

    no Elastic::Doc;

=cut

=head1 INTRODUCTION TO Elastic::Model

If you are not familiar with L<Elastic::Model>, you should start by reading
L<Elastic::Manual::Intro>.

The rest of the documentation on this page explains how to use the
L<Elastic::Doc> module itself.

=head1 DESCRIPTION

Elastic::Doc prepares your object classes (eg C<MyApp::User>) for storage in
ElasticSearch, by:

=over

=item *

applying L<Elastic::Model::Role::Doc> to your class and
L<Elastic::Model::Meta::Doc> to its metaclass

=item *

adding keywords to your attribute declarations, to give you control over how
they are indexed (see L<Elastic::Manual::Attributes>)

=item *

wrapping your accessors to allow auto-inflation of embedded objects (see
L<Elastic::Model::Meta::Instance>).

=item *

exporting the L</"has_mapping"> function to allow you to customize the
special "meta-fields" in the type mapping in ElasticSearch

=back

=head1 EXPORTED FUNCTIONS

=head3 has_mapping

C<has_mapping> can be used to customize the special "meta-fields" (ie not
attr/field-specific) in the type mapping. For instance:

    has_mapping {
        _source => {
            compress    => 1,
            includes    => ['path1.*','path2.*'],
            excludes    => ['path3.*']
        },
        _ttl => {
            enabled     => 1,
            default     => '2h'
        },
        numeric_detection   => 1,
        date_detection      => 0,
    };

B<Warning:> Use C<has_mapping> with caution. L<Elastic::Model> requires
certain settings to be active to work correctly.

See the "Fields" section in L<Mapping|http://www.elasticsearch.org/guide/reference/mapping/> and
L<Root object type|http://www.elasticsearch.org/guide/reference/mapping/root-object-type.html>
for more information about what options can be configured.

=head1 SEE ALSO

=over

=item *

L<Elastic::Model::Role::Doc>

=item *

L<Elastic::Model>

=item *

L<Elastic::Meta::Trait::Field>

=item *

L<Elastic::Model::TypeMap::Default>

=item *

L<Elastic::Model::TypeMap::Moose>

=item *

L<Elastic::Model::TypeMap::Objects>

=item *

L<Elastic::Model::TypeMap::Structured>

=item *

L<Elastic::Model::TypeMap::ES>

=item *

L<Elastic::Model::TypeMap::Common>

=back
