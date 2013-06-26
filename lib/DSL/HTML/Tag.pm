package DSL::HTML::Tag;
use strict;
use warnings;

use DSL::HTML::Text;
use Scalar::Util qw/blessed/;

my %NO_SHORT = map {$_ => 1} qw{
    script
    head
    body
};

sub name       { shift->{name}       }
sub attributes { shift->{attributes} }
sub elements   { shift->{elements}   }

sub element_list { @{ shift->elements }}

sub new {
    my $class = shift;
    my ($name, $params, @elements) = @_;

    my $self = bless {
        name       => $name,
        elements   => [],
        attributes => {},
    }, $class;

    $self->attr( $params );

    for my $element ( @elements ) {
        if ( ref $element ) {
            $self->insert($element);
        }
        else {
            $self->insert(DSL::HTML::Text->new($element));
        }
    }

    return $self;
}

# Shallow clone
sub _clone {
    my $self = shift;
    my $class = blessed $self;
    return bless { %$self }, $class;
}

sub as_html {
    my $self = shift;
    my ( $level, $indent ) = @_;

    my $lead = ($indent eq "\t" ? "\t" : ' ' x $indent) x $level;

    return $self->empty($lead) unless $self->element_list;

    my $open = $self->open($lead);
    my $child_level = $self->name =~ m/^pre$/i ? 0 : $level + 1;

    return join "" => (
        "$lead<$open>\n",
        (map { $_->as_html($child_level, $indent) } $self->element_list),
        "$lead</" . $self->name . ">\n"
    );
}

sub empty {
    my $self = shift;
    my ($lead) = @_;
    my $name = $self->name;
    my $open = $self->open;

    return "$lead<$open />\n" unless $NO_SHORT{lc($name)};

    return "$lead<$open></$name>\n";
}

sub open {
    my $self = shift;

    my $attr = $self->attributes;
    return join " " => (
        $self->name,
        $self->class ? ('class="' . $self->class_string . '"') : (),
        map { qq|$_="$attr->{$_}"| } sort keys %$attr,
    );
}

sub attr {
    my $self = shift;
    my $new_attrs;
    if ( @_ == 1 && ref $_[0] ) {
        $new_attrs = shift;
        $self->{attributes} = {};
    }
    else {
        $new_attrs = {@_};
    }

    return unless keys %$new_attrs;

    my $attrs = $self->attributes;

    for my $attr (map { lc $_ } keys %$new_attrs) {
        if($attr eq 'class') {
            $self->class( $self->parse_class($new_attrs->{$attr}) );
        }
        else {
            $attrs->{$attr} = $new_attrs->{$attr}
        }
    }
}

sub class {
    my $self = shift;
    if (@_ == 1 && ref $_[0]) {
        $self->{class} = shift;
    }
    elsif( @_ ) {
        push @{$self->{class}} => @_;
    }

    return @{$self->{class} || []};
}

sub class_string {
    my $self = shift;
    my %seen;
    return join " " => map { $seen{$_}++ ? () : $_ } $self->class;
}

sub add_class {
    my $self = shift;
    $self->class( @_ );
}

sub del_class {
    my $self = shift;
    my ($del) = @_;
    $self->class([ grep { $_ ne $del } $self->class ]);
}

sub insert {
    my $self = shift;
    push @{$self->elements} => @_;
}

sub parse_class {
    my $self = shift;
    my ($string) = @_;
    return [split /\s+/, $string];
}

1;

__END__

=head1 NAME

DSL::HTML::Tag - Used internally by L<DSL::HTML>

=head1 NOTES

You should never need to construct this yourself.

=head1 METHODS

=over 4

=item name      

=item attributes

=item elements  

=item element_list

=item as_html

=item empty

=item open

=item attr

=item class

=item class_string

=item add_class

=item del_class

=item insert

=item parse_class

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2013 Chad Granum

DSL-HTML is free software; Standard perl license (GPL and Artistic).

DSL-HTML is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.
