package Elastic::Model::Role::Doc;

use Moose::Role;

use Elastic::Model::Trait::Exclude;
use MooseX::Types::Moose qw(Maybe Bool HashRef);
use Elastic::Model::Types qw(Timestamp UID);
use Scalar::Util qw(refaddr);
use Try::Tiny;
use Time::HiRes();
use Carp;
use namespace::autoclean;

#===================================
has 'uid' => (
#===================================
    isa      => UID,
    is       => 'ro',
    required => 1,
    writer   => '_set_uid',
    traits   => ['Elastic::Model::Trait::Exclude'],
    exclude  => 1,
);

#===================================
has 'timestamp' => (
#===================================
    traits  => ['Elastic::Model::Trait::Field'],
    isa     => Timestamp,
    is      => 'rw',
    exclude => 0
);

#===================================
has '_can_inflate' => (
#===================================
    isa     => Bool,
    is      => 'rw',
    default => 0,
    traits  => ['Elastic::Model::Trait::Exclude'],
    exclude => 1,
);

#===================================
has '_source' => (
#===================================
    isa => Maybe [HashRef],
    is => 'ro',
    traits    => ['Elastic::Model::Trait::Exclude'],
    lazy      => 1,
    exclude   => 1,
    builder   => '_get_source',
    writer    => '_set_source',
    predicate => '_has_source',
);

#===================================
has '_old_value' => (
#===================================
    is        => 'ro',
    isa       => HashRef,
    traits    => ['Elastic::Model::Trait::Exclude'],
    exclude   => 1,
    writer    => '_set_old_value',
    clearer   => '_clear_old_value',
    predicate => '_has_old_value'
);

no Moose::Role;

#===================================
sub has_changed {
#===================================
    my $self = shift;
    if (@_) {
        my $attr = shift;
        my $old = $self->_old_value || {};
        if ( $attr eq "1" or @_ ) {
            $old->{$attr} = shift()
                unless $attr eq "1" || exists $old->{$attr};
            $self->_set_old_value($old);
            return 1;
        }
        return exists $old->{$attr};
    }
    return $self->_has_old_value;
}

#===================================
sub old_value {
#===================================
    my $self = shift;
    my $old = $self->_old_value or return;
    if ( my $attr = shift ) {
        return $old->{$attr};
    }
    return $old;
}

#===================================
sub _get_source {
#===================================
    my $self = shift;
    $self->model->get_doc_source(
        uid            => $self->uid,
        ignore_missing => 1,
        @_
    );
}

#===================================
sub _inflate_doc {
#===================================
    my $self   = $_[0];
    my $source = $self->_source
        or return bless( $self, 'Elastic::Model::Deleted' )->croak;

    $self->_can_inflate(0);
    try {
        $self->model->inflate_object( $self, $source );
    }
    catch {
        $self->_can_inflate(1);
        die $_;
    };
}

#===================================
sub touch {
#===================================
    my $self = shift;
    $self->timestamp( int( Time::HiRes::time * 1000 + 0.5 ) / 1000 );
    $self;
}

#===================================
sub save {
#===================================
    my $self = shift;

    if ( $self->has_changed || !$self->uid->from_store ) {
        $self->touch;
        $self->model->save_doc( doc => $self, @_ )
            and $self->_clear_old_value;
    }
    $self;
}

#===================================
sub overwrite { shift->save( @_, version => 0 ) }
#===================================

#===================================
sub delete {
#===================================
    my $self = shift;
    $self->model->delete_doc( uid => $self->uid, @_ )
        or return;
    bless $self, 'Elastic::Model::Deleted';
}

#===================================
sub has_been_deleted {
#===================================
    my $self = shift;
    $self->uid->from_store or return 0;
    return !( $self->_has_source ? $self->_get_source() : $self->_source );
}

1;

__END__

# ABSTRACT: The role applied to your Doc classes

=head1 SYNOPSIS

=head2 Creating a doc

    $doc = $domain->new_doc(
        user => {
            id      => 123,                 # auto-generated if not specified
            email   => 'clint@domain.com',
            name    => 'Clint'
        }
    );

    $doc->save;
    $uid = $doc->uid;

=head2 Retrieving a doc

    $doc = $domain->get( user => 123 );
    $doc = $model->get_doc( uid => $uid );

=head2 Updating a doc

    $doc->name('John');

    print $doc->has_changed();              # 1
    print $doc->has_changed('name');        # 1
    print $doc->has_changed('email');       # 0
    print $doc->old_value('name');          # Clint

    $doc->save;
    print $doc->has_changed();              # 0

=head2 Deleting a doc

    $doc->delete;
    print $doc->has_been_deleted            # 1


=head1 DESCRIPTION

L<Elastic::Model::Role::Doc> is applied to your "doc" classes (ie those classes
that you want to be stored in ElasticSearch), when you include this line:

    use Elastic::Doc;

This document explains the changes that are made to your class by applying the
L<Elastic::Model::Role::Doc> role.  Also see L<Elastic::Doc>.

=head1 ATTRIBUTES

The following attributes are added to your class:

=head2 uid

The L<uid|Elastic::Model::UID> is the unique identifier for your doc in
ElasticSearch. It contains an L<index|Elastic::Model::UID/"index">,
a L<type|Elastic::Model::UID/"type">, an L<id|Elastic::Model::UID/"id"> and
possibly a L<routing|Elastic::Model::UID/"routing">. This is what is required
to identify your document uniquely in ElasticSearch.

The UID is created when you create your document, eg:

    $doc = $domain->new_doc(
        user    => {
            id      => 123,
            other   => 'foobar'
        }
    );


=over

=item *

C<index> : initially comes from the C<< $domain->name >> - this is changed
to the actual domain name when you save your doc.

=item *

C<type> : comes  from the first parameter passed to
L<new_doc()|Elastic::Model::Domain/"new_doc()"> (C<user> in this case).

=item *

C<id> : is optional - if you don't provide it, then it will be
auto-generated when you save it to ElasticSearch.

=back

B<Note:> the C<namespace_name/type/ID> of a document must be unique.
ElasticSearch can enforce uniqueness for a single index, but when your
L<namespace|Elastic::Model::Namespace> contains multiple indices, it is up
to you to ensure uniqueness.  Either leave the ID blank, in which case
ElasticSearch will generate a unique ID, or ensure that the way you
generate IDs will not cause a collision.

=head2 timestamp

    $timestamp = $doc->timestamp($timestamp);

This stores the last-modified time (in epoch seconds with milli-seconds), which
is set automatically when your doc is saved. The C<timestamp> is indexed
and can be used in queries.

=head2 Private attributes

These private attributes are also added to your class, and are documented
here so that you don't override them without knowing what you are doing:

=head3 _can_inflate

A boolean indicating whether the object has had its attributes values
inflated already or not.

=head3 _source

The raw uninflated source value as loaded from ElasticSearch.

=head3 _old_value

If any attribute value has changed, the original value will be stored in
C<_old_value>. See L</"old_value()"> and L</"has_changed()">.

=head1 METHODS

=head2 save()

    $doc->save( %args );

Saves the C<$doc> to ElasticSearch. If this is a new doc, and a doc with the
same type and ID already exists in the same index, then ElasticSearch
will throw an exception.

If the doc was previously loaded from ElasticSearch, then that doc will be
updated. However, because ElasticSearch uses
L<optimistic locking|http://en.wikipedia.org/wiki/Optimistic_locking>
(ie the doc version number is incremented on every change), it is possible that
another process has already updated the C<$doc> while the current process has
been working, in which case it will throw a conflict error.

For instance:


    ONE                         TWO
    --------------------------------------------------
                                get doc 1-v1
    get doc 1-v1
                                save doc 1-v2
    save doc1-v2
     -> # conflict error

=head3 on_conflict

If you don't care, and you just want to overwrite what is stored in ElasticSearch
with the current values, then use L</overwrite()> instead of L</save()>. If you
DO care, then you can handle this situation gracefully, using the
C<on_conflict> parameter:

    $doc->save(
        on_conflict => sub {
            my ($original_doc,$new_doc) = @_;
            # resolve conflict

        }
    );

The doc will only be saved if it has changed. If you want to force saving
on a doc that hasn't changed, then you can do:

    $doc->touch->save;

=head2 overwrite()

    $doc->overwrite( %args );

L</overwrite()> is exactly the same as L</save()> except it will overwrite
any previous doc, regardless of whether another process has updated the same
doc in the meantime.

=head2 delete()

    $doc->delete;

This will delete the current doc.  If the doc has already been updated
to a new version by another process, it will throw a conflict error.  You
can override this and delete the document anyway with:

    $doc->delete( version => 0 );

The C<$doc> will be reblessed into the L<Elastic::Model::Deleted> class,
and any attempt to access its attributes will throw an error.

=head2 has_been_deleted()

    $bool = $doc->has_been_deleted();

As a rule, you shouldn't delete docs that are currently in use elsewhere in
your application, otherwise you have to wrap all of your code in C<eval>s
to ensure that you're not accessing a stale doc.

However, if you do need to delete current docs, then L</has_been_deleted()>
helps you to determine if the current doc is live or not.  For instance, you
might have an L</on_conflic> handler which looks like this:

    $doc->save(
        on_conflict => sub {
            my ($original, $new) = @_;

            return $original->overwrite
                if $new->has_been_deleted;

            for my $attr ( keys %{ $old->old_value }) {
                $new->$attr( $old->$attr ):
            }

            $new->save
        }
    );

B<Note:> L</has_been_deleted> tried to fetch the document from ElasticSearch,
so (1) it is as costly as calling L<Elastic::Model::Domain/get()> and
(2) it only represents the truth at that moment in time - another process
may already have recreated or deleted the document.

It is a much better approach to remove docs from the main flow of your
application (eg, set a C<status> attribute to C<"deleted">) then physically
delete the docs only after some time has passed.

=head2 touch()

    $doc = $doc->touch()

Updates the L</"timestamp"> to the current time.

=head2 has_changed()

Has the value for any attribute changed?

    $bool = $doc->has_changed;

Has the value of attribute C<$attr_name> changed?

    $bool = $doc->has_changed($attr_name);

Mark the object as changed without specifying an attribute:

    $doc->has_changed(1);

=head2 old_value()

    $old_val    = $doc->old_value($attr_name);
    \%old_vals  = $doc->old_value();

Returns the original value that an attribute had before being changed.  If
called without an attribute name, it returns a hashref whose key names
are the names of the attributes that have changed.

=head2 Private methods

These private methods are also added to your class, and are documented
here so that you don't override them without knowing what you are doing:

=head3 _inflate_doc

Inflates the attribute values from the hashref stored in L</"_source">.

=head3 _get_source / _set_source / _has_source

The raw doc source from ElasticSearch.

=head3 _set_old_value / _clear_old_value / _has_old_value

Accessors for L</"_old_value">.
