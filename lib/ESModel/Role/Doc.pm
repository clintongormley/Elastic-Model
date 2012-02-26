package ESModel::Role::Doc;

use Moose::Role;

use namespace::autoclean;
use ESModel::Trait::Exclude;
use ESModel::Types qw(Timestamp);
use Time::HiRes();

has 'metadata' => (
    isa     => 'ESModel::Doc::Metadata',
    is      => 'ro',
    handles => { id => 'id', type => 'type' }
);

has timestamp => (
    traits  => ['ESModel::Trait::Field'],
    isa     => Timestamp,
    is      => 'rw',
    exclude => 0
);

around 'BUILDARGS' => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    $params{metadata} ||= ESModel::Doc::Metadata->new(@_);
    $class->$orig( \%params );
};

no Moose::Role;

#===================================
sub touch { shift->timestamp( int( Time::HiRes::time * 1000 + 0.5 ) / 1000 ) }
#===================================

#===================================
sub save {
#===================================
    my $self = shift;
    my %args = ref $_[0] ? %{ shift() } : @_;

    $self->touch if $self->meta->timestamp_path;

    my $metadata = $self->metadata;
    my $action = $metadata->from_datastore ? 'index_doc' : 'create_doc';

    my $result = $self->store->$action( $metadata, $self->deflate, \%args );
    $self->metadata->update_from_datastore($result);
}

#===================================
sub delete {
#===================================
    my $self   = shift;
    my %args   = ref $_[0] ? %{ shift() } : @_;
    my $result = $self->store->delete_doc( $self->metadata, \%args );
    $self->metadata->update_from_datastore($result);
}

#===================================
sub deflate {
#===================================
    my ( $self, $seen ) = @_;
    $seen ||= {};

    my $meta = $self->meta;
    my %hash;
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

    my $meta = $class->meta;
    for my $name ( keys %vals ) {
        my $attr = $meta->get_attribute($name);
        $attr->inflator->( $vals{$name} );
        if ( my $init = $attr->init_arg ) {
            $vals{$init} = delete $vals{$name};
        }
    }
    return \%vals;
}

1;
