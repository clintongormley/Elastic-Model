package ESModel;

use Moose();
use Moose::Exporter();
use Carp;
use namespace::autoclean;

my $init_meta = Moose::Exporter->build_import_methods(
    install         => [qw(import unimport)],
    class_metaroles => { class => ['ESModel::Meta::Class::Model'] },
    with_meta       => [qw(has_domain analyzer tokenizer filter char_filter)],
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
sub has_domain {
#===================================
    my $meta   = shift;
    my $name   = shift or croak "No domain name passed to has_domain";
    my $types = ref $_[0] ? shift : {@_};

    croak "No types specified for domain $name"
        unless %$types;

    $meta->add_domain( $name => $types );
}

#===================================
sub analyzer    { shift->add_analyzer( shift,    {@_} ) }
sub tokenizer   { shift->add_tokenizer( shift,   {@_} ) }
sub filter      { shift->add_filter( shift,      {@_} ) }
sub char_filter { shift->add_char_filter( shift, {@_} ) }
#==================================

1
