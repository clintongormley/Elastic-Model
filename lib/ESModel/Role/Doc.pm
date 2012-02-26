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
#===================================

#===================================
#===================================
    my $self = shift;



#===================================
sub save {
#===================================
    my $self = shift;

    ## if ID changed, then delete before saving
    my $action = $self->is_from_datastore ? 'index' : 'create';
    $self->update_timestamp if $self->meta->timestamp_path;
    $self->_write( $action, $self->_doc_metadata( data => $self->deflate ) );
}

#===================================
sub delete {
#===================================
    my $self = shift;
    $self->update_timestamp if $self->meta->timestamp_path;
    $self->_write( 'delete', $self->_doc_metadata );
}

#===================================
sub _write {
#===================================
    my ( $self, $action, $params ) = @_;
    my $result = $self->_es->$action($params);
    $self->$_( $result->{"_$_"} ) for ( 'index', 'type', 'id', 'version' );
    $self->_set_is_from_datastore(1);
    return $self;
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
