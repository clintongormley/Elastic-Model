package Elastic::Model::Role::Doc;

use Moose::Role;

use Elastic::Model::Trait::Exclude;
use MooseX::Types::Moose qw(Bool HashRef);
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
        $self->model->save_doc( doc => $self, @_ );
        $self->_clear_old_value;
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

    $doc = $domain->new_doc(
        user => {
            id      => 123,                 # auto-generated if not specified
            email   => 'clint@domain.com',
            name    => 'Clint'
        }
    );

    $doc->save;
    $uid = $doc->uid;

    $doc = $domain->get($uid);

    $doc->name('John');
    print $doc->has_changed();              # 1
    print $doc->has_changed('name');        # 1
    print $doc->has_changed('email');       # 0
    print $doc->old_value('name');          # Clint

    $doc->save;
    print $doc->has_changed();              # 0

=head1 DESCRIPTION

L<Elastic::Model::Role::Doc> is applied to your "doc" classes (ie those classes
that you want to be stored in ElasticSearch), when you include this line:

    use Elastic::Doc;

This document explains the changes that are made to your class by applying the
L<Elastic::Model::Role::Doc> role.  For other effects, see L<Elastic::Doc>.

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

    $doc->save(%args);

Saves the C<$doc> to ElasticSearch. If the doc was previously loaded from
ElasticSearch, then it uses L<Elastic::Model::Role::Store/"index_doc()">
otherwise it uses L<Elastic::Model::Role::Store/"create_doc()">, which
will throw an exception if a doc with the same UID already exists.

The doc will only be saved if it has changed. If you want to force saving
on a doc that hasn't changed, then you can do:

    $doc->touch->save;

TODO: VERSIONING.

=head2 delete()

TODO: NOT YET IMPLEMENTED

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

    $old_val  = $doc->old_value($attr_name);
    $old_vals = $doc->old_value();

Returns the original value that an attribute had before being changed.  If
called without an attribute name, it returns a hashref whose key names
are the names of the attributes that have changed.

=head2 Private methods

These private methods are also added to your class, and are documented
here so that you don't override them without knowing what you are doing:

=head3 _inflate_doc

Inflates the attribute values from the hashref stored in L</"_source">.

=head3 _get_source

Loads the raw doc source from ElasticSearch.

=head3 _set_source

Writer for L</"_source">.

=head3 _set_old_value / _clear_old_value / _has_old_value

Accessors for L</"_old_value">.
