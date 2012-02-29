package ESModel::Doc::UID;

use Moose;
use MooseX::Types::Moose qw(:all);
use namespace::autoclean -also => [ '_encode', '_decode' ];

has index => ( is => 'ro', isa => Str, required => 1, writer => '_index' );
has type  => ( is => 'ro', isa => Str, required => 1, writer => '_type' );
has id      => ( is => 'ro', isa => Maybe [Str], writer => '_id' );
has version => ( is => 'ro', isa => Maybe [Int], writer => '_version' );
has routing => ( is => 'ro', isa => Maybe [Str] );
has parent  => ( is => 'ro', isa => Maybe [Str] );
has from_store => ( is => 'ro', isa => Bool, writer => '_from_store' );

no Moose;

## TODO: if anything in the uid changes, we may need to delete the obejct
## before saving it

## TODO: remove parent - routing is sufficient

our @UID_attrs = qw(index type id parent routing);
our @UID_version_attrs = ( @UID_attrs, 'version' );

#===================================
sub new_from_store {
#===================================
    my $class = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    $class->new(
        from_store => 1,
        parent     => $params{fields}{parent},
        routing    => $params{fields}{routing},
        map { $_ => $params{"_$_"} } qw(index type id version)
    );
}

#===================================
sub update_from_store {
#===================================
    my $self   = shift;
    my $params = shift;
    $self->$_( $params->{$_} ) for qw(_index _type _id _version);
    $self->_from_store(1);
    $self;
}

#===================================
sub as_params {
#===================================
    my $self = shift;
    my %vals;
    for (@UID_attrs) {
        my $val = $self->$_ or next;
        $vals{$_} = $val if defined $val;
        next unless defined $val;
    }
    return %vals;
}

#===================================
sub as_version_params {
#===================================
    my $self = shift;
    my %vals;
    for (@UID_version_attrs) {
        my $val = $self->$_ or next;
        $vals{$_} = $val if defined $val;
        next unless defined $val;
    }
    return %vals;
}

#===================================
sub as_string {
#===================================
    my $self = shift;
    my $id = $self->id or return undef;
    no warnings 'uninitialized';
    return join ";", map {
        my $val = $self->$_;
        defined $val ? "$_:" . _encode($val) : ()
    } @UID_attrs;
}

#===================================
sub as_version_string {
#===================================
    my $self = shift;
    my $id = $self->id or return undef;
    no warnings 'uninitialized';
    return join ";", map {
        my $val = $self->$_;
        defined $val ? "$_:" . _encode($val) : ()
    } @UID_version_attrs;
}

#===================================
sub new_from_string {
#===================================
    my $class = shift;
    my %params = map { /^(\w+):(.+)?/; $1, _decode($2) } split /;/, shift();
    $class->new( \%params );
}

my %encode = ( ':' => '::', ';' => ':_' );
my %decode = ( ':' => ':',  '_' => ';' );
#===================================
sub _encode {
#===================================
    my $val = shift;
    if ($val) {
        $val =~ s/([:;])/$encode{$1}/ge;
    }
    return $val;
}

#===================================
sub _decode {
#===================================
    my $val = shift;
    if ($val) {
        $val =~ s/:([:_])/$decode{$1}/ge;
    }
    return $val;
}

1;
