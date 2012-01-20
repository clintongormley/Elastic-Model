package ESModel::Role::Type;

use Moose::Role;
use namespace::autoclean;

#===================================
sub deflate {
#===================================
    my ( $self, $seen ) = @_;
    $seen ||= {};
    my $meta = $self->meta;
    my $mi   = Class::MOP::Class->initialize( ref($self) )->get_meta_instance;

    my %hash = ( __CLASS__ => $meta->identifier );
    for my $attr ( $meta->get_all_attributes ) {
        next if $attr->exclude;
        my $name = $attr->name;
        my $value;
        if ( $attr->safe_access ) {
            next unless $attr->is_initialized($self);
            $value = $attr->get_value($self);
        }
        else {
            next unless $mi->is_slot_initialized( $self, $name );
            $value = $mi->get_slot_value( $self, $name );
        }

        if ( my $deflator = $attr->deflator ) {
            $hash{$name} = $deflator->( $value, $seen );
        }
        else {
            $hash{$name} = $value;
        }
    }
    return \%hash;
}

#===================================
sub inflate {
#===================================
    my $class = shift;
    my $vals  = shift;
    $class = delete $vals->{__CLASS__};

    my $meta = $class->meta;
    my $mi   = Class::MOP::Class->initialize($class)->get_meta_instance;
    my $self = $mi->create_instance;

    for my $attr ( $meta->get_all_attributes ) {
        my $name = $attr->name;
        next unless exists $vals->{$name};
        my $val = $vals->{$name};
        if ( my $inflator = $attr->inflator ) {
            $val = $inflator->($val);
        }
        if ( $attr->safe_access ) {
            $self->$name($val);
        }
        else {
            $mi->set_slot_value( $self, $name, $val );
        }
    }
    return $self;
}

1;
