package ESModel::Doc::UID;

use Moose;
use MooseX::Types::Moose qw(:all);
use namespace::autoclean -also => [ '_encode', '_decode' ];

has index => ( isa => Str, is => 'rw', required => 1, );
has type  => ( isa => Str, is => 'rw', required => 1 );
has id      => ( isa => Maybe [Str], is => 'rw' );
has version => ( isa => Maybe [Int], is => 'rw' );
has routing => ( isa => Maybe [Str], is => 'rw' );
has parent  => ( isa => Maybe [Str], is => 'rw' );
has from_datastore => ( isa => Bool, is => 'rw' );

no Moose;

## TODO: if anything in the uid changes, we may need to delete the obejct
## before saving it

## TODO: remove parent - routing is sufficient

our @UID_attrs = qw(index type id parent routing);
our @UID_version_attrs = ( @UID_attrs, 'version' );

#===================================
sub new_from_datastore {
#===================================
    my $class = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    $class->new(
        parent         => $params{fields}{parent},
        routing        => $params{fields}{routing},
        from_datastore => 1,
        map { $_ => $params{"_$_"} } qw(index type id version)
    );
}

#===================================
sub update_from_datastore {
#===================================
    my $self   = shift;
    my $params = shift;
    $self->$_( $params->{"_$_"} ) for qw(index type id version);
    $self->from_datastore(1);
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
