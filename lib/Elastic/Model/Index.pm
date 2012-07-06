package Elastic::Model::Index;

use Carp;
use Moose;
with 'Elastic::Model::Role::Index';

use namespace::autoclean;

no Moose;

#===================================
sub create {
#===================================
    my $self   = shift;
    my $params = $self->index_config(@_);

    $self->es->create_index($params);
    return $self;
}

#===================================
sub reindex {
#===================================
    my $self = shift;
    my %args
        = @_ != 1 ? @_
        : !ref $_[0] ? ( domain => shift() )
        : ref $_[0] eq 'HASH' ? %{ shift() }
        :                       ( view => shift() );

    my $verbose = !$args{quiet};
    my $view    = $args{view};
    my $scan    = $args{scan} || '2m';
    my $size    = $args{size} || 1000;

    unless ($view) {
        my $domain = $args{domain}
            or croak "No (view) or (domain) passed to reindex()";
        $view = $self->model->view( domain => $domain );
    }

    $view = $view->size($size)
        unless $view->_has_size;

    # if view has a filter already, then combine it with the query
    # before setting the new filter
    $view = $view->query( $view->_build_query )
        if $view->filter;

    unless ( $self->exists ) {
        print "Creating index (" . $self->name . ")\n"
            if $verbose;
        $self->create();
    }

    my $transform = $args{transform};
    my $index_map = $self->_index_names( $view, $args{index_map} );
    if ( my $used = $self->_used_index_names( $view, $index_map ) ) {
        if ($verbose) {
            print join "\n", "Remapping UID indices:",
                map { "   $_ -> " . $used->{$_} }
                sort keys %$used;
            print "\n";
        }
        $transform = $self->uid_updater( $used, $transform );
    }

    $self->model->es->reindex(
        dest_index => $self->name,
        source     => $view->scan($scan)->as_elements,
        bulk_size  => $view->size,
        quiet      => !$verbose,
        transform  => $transform,
        map { $_ => $args{$_} } qw(on_conflict on_error),
    );

    my $repoint = $args{repoint_uids}
        or return;

    $self->repoint_uids(
        index_map => $index_map,
        quiet     => $args{quiet},
        scan      => $scan,
        size      => $size,
        view      => ref $repoint ? $repoint : undef,
        map { $_ => $args{"uid_$_"} } qw(on_conflict on_error),
    );

}

#===================================
sub repoint_uids {
#===================================
    my ( $self, %args ) = @_;

    my $map = $args{index_map}
        or croak "No (index_map) passed to repoint_uids";

    my %exclude = ( $self->name => 1, %$map );
    my $verbose = !$args{quiet};
    my $scan    = $args{scan} || '2m';
    my $view    = $args{view} || $self->model->view;
    my $size    = $args{size} || 1000;

    $view = $view->query( $view->_build_query )
        if $view->filter;

    $view = $view->size($size) unless $view->_has_size;
    $view = $view->filterb( 'uid.index' => [ keys %$map ] );

    my @indices
        = grep { !$exclude{$_} } $self->_values_in_field( $view, '_index' );

    print "\nRepointing UIDs to use index " . $self->name . "\n"
        if $verbose;

    unless (@indices) {
        print "No indices to update\n" if $verbose;
        return;
    }

    $view = $view->domain(@indices);

    my $transform = $self->uid_updater( $map, sub { $_[0]->{_version}++ } );

    for my $index (@indices) {
        print "Updating index: $index\n" if $verbose;
        $self->model->es->reindex(
            dest_index => $index,
            source     => $view->domain($index)->scan($scan)->as_elements,
            bulk_size  => $size,
            quiet      => !$verbose,
            transform  => $transform,
            map { $_ => $args{$_} } qw(on_conflict on_error),
        );
    }

    print "Finished repointing UIDs\n" if $verbose;
}

#===================================
sub _index_names {
#===================================
    my ( $self, $view, $init ) = @_;

    my $index_name = $self->name;
    my %map = %$init if $init;

    $view = $view->size(0);

    # all indices involved in the source
    $map{$_} ||= $index_name for $self->_values_in_field( $view, '_index' );

    return \%map;

}

#===================================
sub _used_index_names {
#===================================
    my ( $self, $view, $all ) = @_;

    $view = $view->size(0);

    # any uses of these indices in uid.index
    $view = $view->filterb( 'uid.index' => [ keys %$all ] );

    my %map = map { $_ => $all->{$_} }
        $self->_values_in_field( $view, 'uid.index' );

    return keys %map ? \%map : undef;
}

#===================================
sub uid_updater {
#===================================
    my ( $self, $map, $transform ) = @_;
    my $mapper = sub {
        my $doc   = shift;
        my @stack = values %{ $doc->{_source} };

        while ( my $val = shift @stack ) {
            unless ( ref $val eq 'HASH' ) {
                push @stack, @$val if ref $val eq 'ARRAY';
                next;
            }
            my ( $uid, $index );

            if (    $uid = $val->{uid}
                and ref $uid eq 'HASH'
                and $index = $uid->{index}
                and $uid->{type} )
            {
                if ( my $new = $map->{$index} ) {
                    $uid->{index} = $new;
                }
            }
            else {
                push @stack, values %$val;
            }
        }
        return $doc;
    };

    return $mapper unless $transform;

    return sub {
        my $no_remap = 0;
        $transform->( @_, $no_remap );
        $mapper->(@_) unless $no_remap;
    };

}

#===================================
sub _values_in_field {
#===================================
    my ( $self, $view, $field, $size ) = @_;
    $size ||= 100;

    my $facet
        = $view->facets(
        field => { terms => { field => $field, size => $size } } )
        ->search->facet('field');

    if ( my $missing = $facet->{missing} ) {
        return $self->view( $field, $size + $missing );
    }

    return map { $_->{term} } @{ $facet->{terms} };
}

1;

__END__

# ABSTRACT: Create and administer indices in ElasticSearch

=head1 SYNOPSIS

    $index = $model->namespace('myapp')->index;
    $index = $model->namespace('myapp')->index('index_name');

    $index->create( settings => \%settings );

    $index->reindex( 'old_index' );

    $index->reindex(
        domain       => 'old_index',
        repoint_uids => 1
    );

See also L<Elastic::Model::Role::Index/SYNOPSIS>.

=head1 DESCRIPTION

L<Elastic::Model::Index> objects are used to create and administer indices
in an ElasticSearch cluster.

See L<Elastic::Model::Role::Index> for more about usage.
See L<Elastic::Manual::Scaling> for more about how indices can be used in your
application.

=head1 METHODS

=head2 create()

    $index = $index->create();
    $index = $index->create( settings => \%settings, types => \@types );

Creates an index called L<name|Elastic::Role::Model::Index/name> (which
defaults to C<< $namespace->name >>).

The L<type mapping|Elastic::Manual::Terminology/Mapping> is automatically
generated from the attributes of your doc classes listed in the
L<namespace|Elastic::Model::Namespace>.  Similarly, any
L<custom analyzers|Elastic::Model/"Custom analyzers"> required
by your classes are added to the index
L<\%settings|http://www.elasticsearch.org/guide/reference/api/admin-indices-update-settings.html>
that you pass in:

    $index->create( settings => {number_of_shards => 1} );

To create an index with a sub-set of the types known to the
L<namespace|Elastic::Model::Namespace>, pass in a list of C<@types>.

    $index->create( types => ['user','post' ]);

=head2 reindex()

    # reindex $domain_name to $index->name
    $index->reindex( $domain_name );

    # reindex the data returned by $view to $index->name
    $index->reindex( $view );

    # more options
    $index->reindex(
        domain          => $domain,
    OR  view            => $view,

        size            => 1000,
        repoint_uids    => 1 | $other_view
        transform       => sub {...},
        scan            => '2m',
        quiet           => 0,

        on_conflict     => sub {...} | 'IGNORE'
        on_error        => sub {...} | 'IGNORE'
        uid_on_conflict => sub {...} | 'IGNORE'
        uid_on_error    => sub {...} | 'IGNORE'
    );

While you can add to the L<mapping|Elastic::Manual::Terminology/Mapping> of
an index, you can't change what is already there. Especially during development,
you will need to reindex your data to a new index.

L</reindex()> reindexes your data from L<domain|Elastic::Manual::Terminology/Domain>
C<$domain_name> (or the results returned by L<view|Elastic::Model::View> C<$view>)
into an index called C<< $index->name >>. The new index is created if it
doesn't already exist.

See L<Elastic::Manual::Reindex> for more about reindexing strategies. The
documentation below explains what each parameter does:

=over

=item size

The C<size> parameter defaults to 1,000. It has two effects: it controls
how many documents are pulled from the C<domain> or C<view>, and how many
documents are batched together to index into the new index.

You can control the first separately by setting a
L<size|Elastic::Model::View/size> on the C<view>:

    $index->reindex(
        size    => 200                  # index 200 at a time
        view    => $model->view(
            domain => 'myapp_v1',
            size   => 100               # pull max of 100 * primary_shards
        ),
    );

B<Note:> documents are pulled from the C<domain>/C<view> using
L<Elastic::Model::View/scan()>, which can pull a maximum of
L<size|Elastic::Model::View/size> C<* number_of_primary_shards> in a single
request.  If you have large docs or underpowered servers, you may want to
change the L<size|Elastic::Model::View/size> parameter.

=item scan

C<scan> is the same as L<Elastic::Model::View/scan> - it controls how long
ElasticSearch should keep the "scroll" live between requests.  Defaults to
'2m'.  Increase this if the reindexing process is slow and you get
scroll timeouts.

=item repoint_uids

If true, L</repoint_uids()> will be called automatically to update any
L<UIDs|Elastic::Model::UID> (which point at the old index) in indices other
than the ones currently being reindexed.

    $index->reindex(
        domain       => 'myapp_v1',
        repoint_uids => 1                # updates UIDs in any other_index which
                                         # point to 'myapp_v1'
    );

For more advanced control, you can pass a L<view|Elastic::Model::View>:

    my $repoint = $model->view->filterb(...some subset of documents...);
    $index->reindex(
        domain       => 'myapp_v1',
        repoint_uids => $repoint         # updates UIDs just in $repoint which
                                         # point to 'myapp_v1'
    );

=item transform

C<transform> accepts a coderef which is called before indexing each doc.
You can use it to make structural changes to the doc, for instance, changing
attribute C<foo> from a C<ArrayRef[Str]> to a C<Str>:

    $index->reindex(
        domain      => 'myapp_v1',
        transform   => sub {
            my ($doc) = @_;
            $doc->{_source}{foo} = $doc->{_source}{foo}[0]
        }
    );

You can also disable the automatic UID remapper with the second parameter:

    $index->reindex(
        domain      => 'myapp_v1',
        transform   => sub {
            my ($doc) = @_;
            $_[1]     = 1;  # disable UID remapper
            $doc->{_source}{foo} = $doc->{_source}{foo}[0]
        }
    );

=item on_conflict / on_error

If you are indexing to the new index at the same time as you are reindexing,
you may get document conflicts.  You can handle the conflicts with a coderef
callback, or ignore them by by setting C<on_conflict> to C<'IGNORE'>:

    $index->reindex(
        domain      => 'myapp_v2',
        on_conflict => 'IGNORE',
    );

Similarly, you can pass an C<on_error> handler which will handle other errors,
or all errors if no C<on_conflict> handler is defined.

See L<ElasticSearch/Error handlers> for more.

=item uid_on_conflict / uid_on_error

These work in the same way as the C<on_conflict> or C<on_error> handlers,
but are passed to L</repoint_uids()> if C<repoint_uids> is true.

=item quiet

By default, L</reindex()> prints out progress information.  To silence this,
set C<quiet> to true:

    $index->reindex(
        domain  => 'myapp_v2',
        quiet   => 1
    );

=back

=head2 repoint_uids()

    $index->repoint_uids(
        index_map   => \%index_map,
        view        => $view,
        scan        => '2m',
        size        => 1000,
        quiet       => 0,

        on_conflict => sub {...} | 'IGNORE'
        on_error    => sub {...} | 'IGNORE'
    )

The purpose of L</repoint_uids()> is to update L<UIDs|Elastic::Model::UID> to
point to an old index which has been reindexed.
Normally, it would be called automatically from L</reindex()>.
However, for more fine-grained control, you can call L</repoint_uids()>
yourself.

Parameters:

=over

=item index_map

This is a required parameter, and maps old index names to new.  For instance:

    $index->repoint_uids(
        index_map => {
            old_index_1 => 'new_index',
            old_index_2 => 'new_index',
        }
    );

=item view

Normally, all L<domains|Elastic::Manual::Terminology/Domain> known to the
L<model|Elastic::Manual::Terminology/Model> will be updated.  However, if you
want to restrict which docs are updated, you can pass in a
L<view|Elastic::Model::View> instead.

    $index->repoint_uids(
        index_map   => \%index_map,
        view        => $model->view->filterb(....)
    );

=item size

This is the same as the C<size> parameter to L</reindex()>.

=item scan

This is the same as the C<scan> parameter to L</reindex()>.

=item quiet

This is the same as the C<quiet> parameter to L</reindex()>.

=item on_conflict / on_error

These are the same as the C<on_conflict> and C<on_error> handlers
in L</reindex()>.

=back

=head2 uid_updater()

    $coderef = $index->uid_updater(\%map);
    $coderef = $index->uid_updater(\%map,$transform);

L</uid_updater()> is used by L</reindex()> and L</repoint_uids()> to update
the C<index> value of any L<UIDs|Elastic::Model::UID> to point to a new index.
It accepts a C<\%map> of index names, eg:

    {
        old_index_1  => 'new_index',
        old_index_2  => 'new_index'
    }

It accepts a second optional C<$transform> parameter, which should be
a coderef.  C<$transform> (if passed) will be called (before the UID updater)
for each doc in the reindexing process, with the raw ElasticSearch doc as its
first argument.

The second argument is used as a flag for disabling the the automatic UID
remapper:

    $coderef = $index->uid_updater(
        \%index_map,
        sub {
            my ($doc) = @_;
            $_[1]     = 1;      # disable UID remapper

        }
    );

=head1 IMPORTED ATTRIBUTES

Attributes imported from L<Elastic::Model::Role::Index>

=head2 L<namespace|Elastic::Model::Role::Index/namespace>

=head2 L<name|Elastic::Model::Role::Index/name>

=head1 IMPORTED METHODS

Methods imported from L<Elastic::Model::Role::Index>

=head2 L<close()|Elastic::Model::Role::Index/close()>

=head2 L<open()|Elastic::Model::Role::Index/open()>

=head2 L<refresh()|Elastic::Model::Role::Index/refresh()>

=head2 L<delete()|Elastic::Model::Role::Index/delete()>

=head2 L<update_analyzers()|Elastic::Model::Role::Index/update_analyzers()>

=head2 L<update_settings()|Elastic::Model::Role::Index/update_settings()>

=head2 L<delete_mapping()|Elastic::Model::Role::Index/delete_mapping()>

=head2 L<is_alias()|Elastic::Model::Role::Index/is_alias()>

=head2 L<is_index()|Elastic::Model::Role::Index/is_index()>

=head1 SEE ALSO

=over

=item *

L<Elastic::Model::Role::Index>

=item *

L<Elastic::Model::Alias>

=item *

L<Elastic::Model::Namespace>

=item *

L<Elastic::Manual::Scaling>

=back
