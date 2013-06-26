package DSL::HTML::Rendering;
use strict;
use warnings;

use DSL::HTML::Tag;

use Carp qw/croak/;
our @CARP_NOT = qw/DSL::HTML DSL::HTML::Template DSL::HTML::Tag/;

sub template  { shift->{template}  }
sub head      { shift->{head}      }
sub body      { shift->{body}      }
sub tag_stack { shift->{tag_stack} }
sub css_seen  { shift->{css_seen}  }
sub js_seen   { shift->{js_seen}   }
sub css_ref   { shift->{css_ref}   }
sub js_ref    { shift->{js_ref}    }

my @STACK;
sub current {
    return $STACK[-1];
}

sub new {
    my $class = shift;
    my ( $template ) = @_;

    my $body = DSL::HTML::Tag->new(body => {});
    my $head = DSL::HTML::Tag->new(head => {});

    return bless {
        template  => $template,
        tag_stack => [$body],
        head      => $head,
        body      => $body,
        css_ref   => [],
        js_ref    => [],
        css_seen  => {},
        js_seen   => {},
    }, $class;
}

sub args {
    my $self = shift;
    $self->{args} = [@_] if @_;
    return @{$self->{args}};
}

sub compile {
    my $self = shift;
    my (@args) = @_;

    $self->build(@args);
    return $self->as_html;
}

sub include {
    my $self = shift;
    my (@args) = @_;

    my $current = current();
    croak "Cannot include template, no parent template"
        unless $current;

    $self->push_tag(DSL::HTML::Tag->new(root => {}));
    $self->build(@args);

    # This will be root tag
    $current->insert( $self->peek_tag->element_list );

    $current->add_css( $self->css_list );
    $current->add_js( $self->js_list );
    $current->head->insert( $self->head->element_list );
    $current->body->insert( $self->body->element_list );

    return;
}

sub build {
    my $self = shift;
    my (@args) = @_;

    $self->args(@args);

    push @STACK => $self;
    my $success = eval {
        $self->template->block->($self, @args);
        1;
    };
    my $error = $@;
    pop @STACK;
    die $error unless $success;
}

sub as_html {
    my $self = shift;
    my $head = $self->build_head;
    chomp(my $body = $self->body->as_html(1, $self->template->indent));
    return <<"    EOT";
<html>
$head
$body
</html>
    EOT
}

sub build_head {
    my $self = shift;
    my $head = $self->head->_clone;

    for my $css ($self->css_list) {
        my $tag = DSL::HTML::Tag->new(
            link => {
                rel  => 'stylesheet',
                type => 'text/css',
                href => $css,
            }
        );
        $head->insert($tag);
    }

    for my $js ($self->js_list) {
        my $tag = DSL::HTML::Tag->new(
            script => { src => $js },
        );
        $head->insert($tag);
    }

    return $head->as_html(1, $self->template->indent);
}

sub insert {
    my $self = shift;
    $self->peek_tag->insert(@_);
}

sub push_tag {
    my $self = shift;
    my ($tag) = @_;
    push @{$self->tag_stack} => $tag;
}

sub pop_tag {
    my $self = shift;
    pop @{$self->tag_stack};
}

sub peek_tag {
    my $self = shift;
    return $self->tag_stack->[-1];
}

sub js_list {
    my $self = shift;
    return @{ $self->js_ref };
}

sub css_list {
    my $self = shift;
    return @{ $self->css_ref };
}

sub add_css {
    my $self = shift;
    my $seen = $self->css_seen;
    my $ref  = $self->css_ref;
    for my $file ( @_ ) {
        next if $seen->{$file}++;
        push @$ref => $file;
    }
}

sub add_js {
    my $self = shift;
    my $seen = $self->js_seen;
    my $ref  = $self->js_ref;
    for my $file ( @_ ) {
        next if $seen->{$file}++;
        push @$ref => $file;
    }
}

1;

__END__

=head1 NAME

DSL::HTML:: - Used internally by L<DSL::HTML>

=head1 NOTES

You should never need to construct this yourself.

=head1 METHODS

=over 4

=item template 

=item head     

=item body     

=item tag_stack

=item css_seen 

=item js_seen  

=item css_ref  

=item js_ref   

=item current

=item args

=item compile

=item include

=item build

=item as_html

=item build_head

=item insert

=item push_tag

=item pop_tag

=item peek_tag

=item js_list

=item css_list

=item add_css

=item add_js

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2013 Chad Granum

DSL-HTML is free software; Standard perl license (GPL and Artistic).

DSL-HTML is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.
