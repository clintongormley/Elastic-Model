package ESModel::Role::Doc;

use Moose::Role;
use namespace::autoclean;
use ESModel::Meta::Attribute::Trait::Exclude;
use ESModel::Types qw(ES Timestamp);
use Time::HiRes();

has model => (
    does     => 'ESModel::Role::Model',
    is       => 'rw',
    required => 1,
    weak_ref => 1,
);

has is_from_datastore => (
    isa     => 'Bool',
    is      => 'ro',
    writer  => '_set_is_from_datastore',
    default => 0
);

#has 'id_has_changed' => (
#    isa     => 'Bool',
#    is      => 'ro',
#    writer  => '_set_id_has_changed',
#    default => 0
#);

has id => ( isa => 'Str', is => 'rw', trigger => \&_id_changed );
has source => ( isa => 'ESModel::Source', is => 'rw', lazy_build => 1 );
has index  => ( isa => 'Str',             is => 'rw', required   => 1, );
has type   => ( isa => 'Str',             is => 'rw', required   => 1 );
has timestamp => (
    traits  => ['ESModel::Meta::Attribute::Trait::Field'],
    isa     => Timestamp,
    is      => 'rw',
    exclude => 0
);

has version => ( isa => 'Int', is => 'rw' );
has routing => ( isa => 'Str', is => 'rw', predicate => 'has_routing' );
has parent_id => (
    isa       => 'Str',
    is        => 'rw',
    trigger   => sub { shift->clear_parent },
    predicate => 'has_parent_id',
);

has parent => (
    does       => 'Maybe[ESModel::Role::Doc]',
    is         => 'rw',
    lazy_build => 1
);

has _es => ( isa => ES, is => 'ro', lazy => 1, builder => '_build_es' );

no Moose::Role;

#===================================
sub _id_changed {
#===================================
    #    my $self = shift;
    #    return unless @_ == 2;
    #    $self->id_has_changed(1);
}

#===================================
sub _build_es { shift->model->es }
#===================================

#===================================
sub _build_source {
#===================================
    my $self = shift;
    $self->model->source( index => $self->index, type => $self->type );
}

#===================================
sub _build_parent {
#===================================
    my $self = shift;
    return unless $self->has_parent_id;
    my $parent_source = $self->model->source(
        index => $self->index,
        type  => $self->meta->parent_type
    );
    $parent_source->get( $self->parent_id );
}

#===================================
sub _doc_metadata {
#===================================
    my $self   = shift;
    my %params = (
        index   => $self->index,
        type    => $self->type,
        id      => $self->id,
        version => $self->version,
    );
    $params{routing} = $self->routing   if $self->has_routing;
    $params{parent}  = $self->parent_id if $self->has_parent_id;
    return { %params, ref $_[0] ? %{ shift() } : @_ };
}

#===================================
sub update_timestamp { shift->timestamp(Time::HiRes::time) }
#===================================

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
