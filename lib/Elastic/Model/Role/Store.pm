package Elastic::Model::Role::Store;

use Moose::Role;

use Elastic::Model::Types qw(ES);
use namespace::autoclean;

#===================================
has 'es' => (
#===================================
    isa      => ES,
    is       => 'ro',
    required => 1,
);

#===================================
sub search          { shift->es->search(@_) }
sub scrolled_search { shift->es->scrolled_search(@_) }
sub delete_by_query { shift->es->delete_by_query(@_) }
#===================================

#===================================
sub get_doc {
#===================================
    my ( $self, $uid, %args ) = @_;
    return $self->es->get(
        fields => [qw(_routing _parent _source)],
        %{ $uid->read_params },
        %args,
    );
}

#===================================
sub doc_exists {
#===================================
    my ( $self, $uid, %args ) = @_;
    return !!$self->es->exists( %{ $uid->read_params }, %args, );
}

#===================================
sub create_doc { shift->_write_doc( 'create', @_ ) }
sub index_doc  { shift->_write_doc( 'index',  @_ ) }
#===================================

#===================================
sub _write_doc {
#===================================
    my ( $self, $action, $uid, $data, %args ) = @_;
    return $self->es->$action(
        data => $data,
        %{ $uid->write_params },
        %args
    );
}

#===================================
sub delete_doc {
#===================================
    my ( $self, $uid, %args ) = @_;
    return $self->es->delete( %{ $uid->write_params }, %args );
}

#===================================
sub bulk {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->bulk(%args);
}

#===================================
sub index_exists {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->index_exists(%args);
}

#===================================
sub create_index {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->create_index(%args);
}

#===================================
sub delete_index {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->delete_index(%args);
}

#===================================
sub refresh_index {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->refresh_index(%args);
}

#===================================
sub open_index {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->open_index(%args);
}

#===================================
sub close_index {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->close_index(%args);
}

#===================================
sub update_index_settings {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->update_index_settings(%args);
}

#===================================
sub get_aliases {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->get_aliases( ignore_missing => 1, %args ) || {};
}

#===================================
sub put_aliases {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->aliases(%args);
}

#===================================
sub get_mapping {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->mapping(%args);
}

#===================================
sub put_mapping {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->put_mapping(%args);
}

#===================================
sub delete_mapping {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->delete_mapping(%args);
}

#===================================
sub reindex {
#===================================
    my ( $self, %args ) = @_;
    return $self->es->reindex(%args);
}

#===================================
sub bootstrap_uniques {
#===================================
    my ( $self, %args ) = @_;

    my $es = $self->es;
    return if $es->index_exists( index => $args{index} );

    $es->create_index(
        index    => $args{index},
        settings => { number_of_shards => 1 },
        mappings => {
            _default_ => {
                _all    => { enabled => 0 },
                _source => { enabled => 0 },
                _type   => { index   => 'no' },
                enabled => 0,
            }
        }
    );
}

#===================================
sub create_unique_keys {
#===================================
    my ( $self, %args ) = @_;
    my %keys = %{ $args{keys} };

    my @docs = map { { type => $_, id => $keys{$_}, data => {} } } keys %keys;

    my %failed;
    $self->es->bulk_create(
        index       => $args{index},
        docs        => \@docs,
        on_conflict => sub {
            my ( $action, $doc ) = @_;
            $failed{ $doc->{type} } = $doc->{id};
        },
        on_error => sub {
            die "Error creating multi unique keys: $_[2]";
        }
    );
    if (%failed) {
        delete @keys{ keys %failed };
        $self->delete_unique_keys( index => $args{index}, keys => \%keys );
    }
    return %failed;
}

#===================================
sub delete_unique_keys {
#===================================
    my ( $self, %args ) = @_;
    my %keys = %{ $args{keys} };

    my @docs = map { { type => $_, id => $keys{$_} } } keys %keys;

    $self->es->bulk_delete(
        index    => $args{index},
        docs     => \@docs,
        on_error => sub {
            die "Error deleting multi unique keys: $_[2]";
        }
    );
    return 1;
}

1;

__END__

# ABSTRACT: Elasticsearch backend for document read/write requests

=head1 DESCRIPTION

All document-related requests to the Elasticsearch backend are handled
via L<Elastic::Model::Role::Store>.

=head1 ATTRIBUTES

=head2 es

    $es = $store->es

Returns the connection to Elasticsearch.

=head1 METHODS

=head2 get_doc()

    $result = $store->get_doc($uid, %args);

Retrieves the doc specified by the L<$uid|Elastic::Model::UID> from
Elasticsearch, by calling L<Search::Elasticsearch::Compat/"get()">. Throws an exception
if the document does not exist.

=head2 doc_exists()

    $bool = $store->doc_exists($uid, %args);

Checks whether the doc exists in ElastciSearch. Any C<%args> are passed through
to L<Search::Elasticsearch::Compat/exists()>.

=head2 create_doc()

    $result = $store->create_doc($uid => \%data, %args);

Creates a doc in the Elasticsearch backend and returns the raw result.
Throws an exception if a doc with the same L<$uid|Elastic::Model::UID>
already exists.  Any C<%args> are passed to L<Search::Elasticsearch::Compat/"create()">

=head2 index_doc()

    $result = $store->index_doc($uid => \%data, %args);

Updates (or creates) a doc in the Elasticsearch backend and returns the raw
result. Any failure throws an exception.  If the L<version|Elastic::Model::UID/"version">
number does not match what is stored in Elasticsearch, then a conflict exception
will be thrown.  Any C<%args> will be passed to L<Search::Elasticsearch::Compat/"index()">.
For instance, to overwrite a document regardless of version number, you could
do:

    $result = $store->index_doc($uid => \%data, version => 0 );

=head2 delete_doc()

    $result = $store->delete_doc($uid, %args);

Deletes a doc in the Elasticsearch backend and returns the raw
result. Any failure throws an exception.  If the L<version|Elastic::Model::UID/"version">
number does not match what is stored in Elasticsearch, then a conflict exception
will be thrown.  Any C<%args> will be passed to L<Search::Elasticsearch::Compat/"delete()">.

=head2 bulk()

    $result = $store->bulk(
        actions     => $actions,
        on_conflict => sub {...},
        on_error    => sub {...},
        %args
    );

Performs several actions in a single request. Any %agrs will be passed to
L<Search::Elasticsearch::Compat/bulk()>.

=head2 search()

    $results = $store->search(@args);

Performs a search, passing C<@args> to L<Search::Elasticsearch::Compat/"search()">.

=head2 scrolled_search()

    $results = $store->scrolled_search(@args);

Performs a scrolled search, passing C<@args> to L<Search::Elasticsearch::Compat/"scrolled_search()">.

