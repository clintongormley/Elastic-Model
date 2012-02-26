package ESModel::Doc::Metadata;

use Moose;
use MooseX::Types::Moose qw(:all);

has index => ( isa => Str, is => 'rw', required => 1, );
has type  => ( isa => Str, is => 'rw', required => 1 );
has id      => ( isa => Maybe [Str], is => 'rw' );
has version => ( isa => Maybe [Int], is => 'rw' );
has routing => ( isa => Maybe [Str], is => 'rw' );
has parent  => ( isa => Maybe [Str], is => 'rw' );
has from_datastore => ( isa => Bool, is => 'rw' );

no Moose;

## if anything in the metadata changes, we may need to delete the obejct
## before saving it

our @UID_attrs = qw(index type id parent routing);
our @UID_version_attrs = ( @UID_attrs, 'version' );

#===================================
sub new_from_datastore {
#===================================
    my $class  = shift;
    my $params = shift;
    $class->new(
        parent         => $params->{fields}{parent},
        routing        => $params->{fields}{routing},
        from_datastore => 1,
        map { $_ => $params->{"_$_"} } qw(index type id version)
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
sub uid_params {
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
sub uid_version_params {
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
sub uid {
#===================================
    my $self = shift;
    my $id = $self->id or return undef;
    no warnings 'uninitialized';
    return join "\0", map { $self->$_ } @UID_attrs;
}

#===================================
sub uid_version {
#===================================
    my $self = shift;
    my $id = $self->id or return undef;
    no warnings 'uninitialized';
    return join "\0", map { $self->$_ } @UID_version_attrs;
}

#===================================
sub from_uid {
#===================================
    my $class = shift;
    my %params;
    @params{@UID_version_attrs} = split /\0/, shift();
    $class->new( \%params );
}

1;
