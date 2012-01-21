package ESModel::Role::Model;

use Moose::Role;
use Carp;
use ESModel::Types qw(ES);
use ElasticSearch();
use namespace::autoclean;

has 'es' => (
    isa        => ES,
    is         => 'ro',
    coerce     => 1,
    lazy_build => 1
);

has '_index_cache' => (
    isa     => 'HashRef',
    traits  => ['Hash'],
    default => sub { {} },
    handles => {
        _get_index   => 'get',
        _cache_index => 'set'
    },
);

#===================================
sub _build_es { ElasticSearch->new }
#===================================

#===================================
sub index {
#===================================
    my $self = shift;
    my $name = shift or croak "No index name passed to index()";

    my $index = $self->_get_index($name);
    unless ($index) {

        my $opts = $self->meta->index($name)
            or croak "Unknow index name '$name'";

        $index = ESModel::Index->new(
            name  => $name,
            model => $self,
            %$opts
        );

        $self->_cache_index($name => $index);
    }
    return $index;
}

1;
