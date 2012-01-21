package ESModel::Role::Type;

use Moose::Role;
use namespace::autoclean;

#===================================
sub deflate {
#===================================
    my ( $self, $seen ) = @_;
    $seen ||= {};
    my $meta = $self->meta;
    my %hash = ( __CLASS__ => $self->meta->identifier );
    for my $attr ( $meta->get_all_attributes ) {
        next if $attr->exclude;
        next unless $attr->has_value($self) || $attr->has_builder($self);
        my $reader = $attr->get_read_method or next;
        my $name = $attr->name;
        $hash{$name} = $attr->deflator->( $self->$reader, $seen );
    }
    return \%hash;
}

#===================================
sub inflate {
#===================================
    my $class = shift;
    my %vals  = %{ shift() };
    $class = delete $vals{__CLASS__} || $class;

    my $meta = $class->meta;
    for my $name ( keys %vals ) {
        my $attr = $meta->get_attribute($name);
        $vals{$name} = $attr->inflator->( $vals{$name} );
        if ( my $init = $attr->init_arg ) {
            $vals{$init} = delete $vals{$name};
        }
    }

    $class->new( \%vals );
}

1;
