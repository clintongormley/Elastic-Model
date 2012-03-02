package ESModel::Role::Doc;

use Moose::Role;
with 'ESModel::Role::ModelAttr';

use namespace::autoclean;
use ESModel::Trait::Exclude;
use ESModel::Types qw(Timestamp);
use Time::HiRes();

has 'uid' => (
    isa     => 'ESModel::Doc::UID',
    is      => 'ro',
    handles => { id => 'id', type => 'type' },
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
    $params{uid}
        ||= ESModel::Doc::UID->new( %params, type => $class->meta->type );
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

    my $uid = $self->uid;
    my $action = $uid->from_store ? 'index_doc' : 'create_doc';

    my $result = $self->model->store->$action( $uid, $self->deflate, \%args );
    $self->uid->update_from_store($result);
    $self;
}

#===================================
sub delete {
#===================================
    my $self   = shift;
    my %args   = ref $_[0] ? %{ shift() } : @_;
    my $result = $self->model->store->delete_doc( $self->uid, \%args );
    $self->uid->update_from_store($result);
    $self;
}

#===================================
sub deflate {
#===================================
    my ( $self, $orig_seen ) = @_;
    my $seen = $orig_seen || { refaddr($self) => 1 };

    my $meta = $self->meta;
    my %hash;
    for my $attr ( $meta->get_all_attributes ) {
        next if $attr->exclude;
        next unless $attr->has_value($self) || $attr->has_builder($self);

        my $val = $attr->get_read_method_ref->($self);
        my $deflated;
        if ( ref $val ) {
            my %seen = %$seen;
            croak "Cannot deflate recursive structures"
                if $seen{ refaddr $val}++;
            $deflated = $attr->deflator->( $val, \%seen );
        }
        else {
            $deflated = $attr->deflator->($val);
        }
        $hash{ $attr->name } = $deflated;
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
        $vals{$name} = $attr->inflator->( $vals{$name} );
        if ( my $init = $attr->init_arg ) {
            $vals{$init} = delete $vals{$name};
        }
    }
    return \%vals;
}

1;
