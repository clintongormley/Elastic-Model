package ESModel;

use Moose();
use Moose::Exporter();
use Carp;
use namespace::autoclean;

my $init_meta = Moose::Exporter->build_import_methods(
    install         => [qw(import unimport)],
    class_metaroles => { class => ['ESModel::Meta::Class::Model'] },
    with_meta       => [
        'has_index', 'analyzer', 'tokenizer',
        'filter',    'char_filter'
    ],
);

#===================================
sub init_meta {
#===================================
    my $class = shift;
    my %p     = @_;
    Moose::Util::ensure_all_roles( $p{for_class}, 'ESModel::Role::Model' );
    $class->$init_meta(%p);
}

#===================================
sub has_index {
#===================================
    my $meta = shift;
    my $name = shift;
    my $types = ref $_[0] ? shift : {@_};

    my @indices = grep {$_} ref $name eq 'ARRAY' ? @$name : $name;
    croak "No index name passed to has_index" unless @indices;

    croak "No types specified for index: " . join( ', ', @indices )
        unless %$types;

    $meta->add_index( $_ => $types ) for @indices;
}

#===================================
sub analyzer    { shift->add_analyzer( shift,    {@_} ) }
sub tokenizer   { shift->add_tokenizer( shift,   {@_} ) }
sub filter      { shift->add_filter( shift,      {@_} ) }
sub char_filter { shift->add_char_filter( shift, {@_} ) }
#==================================

1
