package ESModel::UID;

use Moose;
use MooseX::Types::Moose qw(:all);
use namespace::autoclean;

#===================================
has index => (
#===================================
    is       => 'ro',
    isa      => Str,
    required => 1,
    writer   => '_index'
);

#===================================
has type => (
#===================================
    is       => 'ro',
    isa      => Str,
    required => 1
);

#===================================
has id => (
#===================================
    is     => 'ro',
    isa    => Str,
    writer => '_id'
);

#===================================
has version => (
#===================================
    is     => 'ro',
    isa    => Int,
    writer => '_version'
);

#===================================
has routing => (
#===================================
    is  => 'ro',
    isa => Maybe [Str],
);

#===================================
has from_store => (
#===================================
    is     => 'ro',
    isa    => Bool,
    writer => '_from_store'
);

#===================================
has cache_key => (
#===================================
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_cache_key',
    clearer => '_clear_cache_key',
);

no Moose;

#===================================
sub new_from_store {
#===================================
    my $class = shift;
    my %params = ref $_[0] ? %{ shift() } : @_;
    $class->new(
        from_store => 1,
        routing    => $params{fields}{routing},
        map { $_ => $params{"_$_"} } qw(index type id version)
    );
}

#===================================
sub update_from_store {
#===================================
    my $self   = shift;
    my $params = shift;
    $self->$_( $params->{$_} ) for qw(_index _id _version);
    $self->_from_store(1);
    $self->_clear_cache_key;
    $self;
}

#===================================
sub update_from_uid {
#===================================
    my $self = shift;
    my $uid  = shift;
    $self->$_( $uid->$_ ) for qw( index routing version );
    $self->_from_store(1);
    $self->_clear_cache_key;
    $self;
}

#===================================
sub read_params  { shift->_params(qw(index type id routing)) }
sub write_params { shift->_params(qw(index type id routing version)) }
#===================================

#===================================
sub _params {
#===================================
    my $self = shift;
    my %vals;
    for (@_) {
        my $val = $self->$_ or next;
        $vals{$_} = $val;
    }
    return \%vals;
}

my %encode = ( ':' => '::', ';' => ':_' );
#===================================
sub _build_cache_key {
#===================================
    my $self = shift;
    my $id = $self->id or return undef;
    return join ";", map {
        if ( my $val = $self->$_ )
        {
            $val =~ s/([:;])/$encode{$1}/ge;
            "$_:$val";
        }
    } qw(type id);
}

1;
