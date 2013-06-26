package DSL::HTML;
use strict;
use warnings;

use Carp qw/croak carp/;
use Scalar::Util qw/blessed/;

use Exporter::Declare::Magic qw{
    import
    export
    default_export
    gen_export
    gen_default_export
};

use Devel::Declare::Parser::Fennec;

use DSL::HTML::Template;
use DSL::HTML::Rendering;
use DSL::HTML::Tag;
use DSL::HTML::Text;

our $VERSION = '0.001';

sub after_import {
    my $class = shift;
    my ($importer, $specs) = @_;

    inject_meta( $importer );
}

sub inject_meta {
    my ($importer) = @_;

    return $importer->DSL_HTML
        if $importer->can('DSL_HTML');

    my $meta = {};

    {
        no strict 'refs';
        *{"$importer\::DSL_HTML"} = sub { $meta };
    }

    return $meta;
}

default_export import {
    my $class = shift;

    my $caller = caller;
    my $imeta = inject_meta( $caller );
    my $meta = $class->DSL_HTML;

    my @want = @_ ? @_ : keys %$meta;

    for my $template ( @want ) {
        if ( $imeta->{$template} ) {
            carp "'$template' already defined in class '$caller', not replacing";
            next;
        }
        $imeta->{$template} = $meta->{$template};
    }

    {
        no strict 'refs';
        *{"$caller\::build_template"} = \&build_template;
    }

    return 1;
}

default_export template fennec {
    my $name = shift;
    die "Template name is required" unless $name;
    my ( $params, $block );
    if ( @_ == 1 ) {
        $block = pop @_;
        $params = {};
    }
    else {
        $params = {@_};
        $block = delete $params->{method};
    }

    my $template = DSL::HTML::Template->new($name, $params, $block);
    return $template if defined wantarray;

    caller->DSL_HTML->{$name} = $template;
}

default_export tag fennec {
    my $name = shift;
    croak "tag name is required" unless $name;
    my ( $params, $block );
    if ( @_ == 1 ) {
        $block = pop @_;
        $params = {};
    }
    else {
        $params = {@_};
        $block = delete $params->{method};
    }

    check_nesting('tag');
    my $rendering = DSL::HTML::Rendering->current;

    my $tag;
    if ( $name =~ m/^head$/i ) {
        $tag = $rendering->head;
    }
    elsif( $name =~ m/^body$/i ) {
        $tag = $rendering->body;
    }
    else {
        $tag = DSL::HTML::Tag->new($name, $params);
        $rendering->insert($tag);
    }

    $rendering->push_tag( $tag );
    my @result;
    my $success = eval {
        @result = $block->($tag);
        1;
    };
    my $error = $@;
    $rendering->pop_tag( $tag );
    die $error unless $success;

    $tag->insert( DSL::HTML::Text->new( @result ))
        if @result && !ref $result[0] && !$tag->element_list;

    return;
}

default_export get_template {
    my $name = pop;
    my $from = $_[0] || caller;
    return $from->DSL_HTML->{$name};
}

default_export 'build_template';
sub build_template {
    my ($template, @args) = @_;
    my $caller = caller;

    $template->compile(@args)
        if blessed($template)
        && $template->isa('DSL::HTML::Template');

    croak "No such template '$template'"
        unless $caller->DSL_HTML->{$template};

    return $caller->DSL_HTML->{$template}->compile(@args);
}

default_export include {
    my ($template, @args) = @_;
    my $caller = caller;

    check_nesting('include');

    $template->include(@args)
        if blessed($template)
        && $template->isa('DSL::HTML::Template');

    croak "No such template '$template'"
        unless $caller->DSL_HTML->{$template};

    return $caller->DSL_HTML->{$template}->include(@args);
}

default_export text {
    check_nesting('text');
    DSL::HTML::Rendering->current->insert( DSL::HTML::Text->new( @_ ));
    return;
}

default_export css {
    check_nesting('css');
    DSL::HTML::Rendering->current->add_css( @_ );
    return;
}

default_export js {
    check_nesting('js');
    DSL::HTML::Rendering->current->add_js( @_ );
    return;
}

default_export attr {
    check_nesting('attr');
    DSL::HTML::Rendering->current->peek_tag->attr( @_ );
    return;
}

default_export add_class {
    check_nesting('add_class');
    DSL::HTML::Rendering->current->peek_tag->add_class( @_ );
    return;
}

default_export del_class {
    check_nesting('del_class');
    DSL::HTML::Rendering->current->peek_tag->del_class( @_ );
    return;
}

sub check_nesting {
    my ($sub) = @_;
    return if DSL::HTML::Rendering->current;
    croak "No template stack found, '$sub()' must have been called outside of a template.";
}

1;

__END__

=head1 NAME

DSL::HTML - Declarative DSL(domain specific language) for writing HTML
templates within perl.

=head1 EARLY VERSION WARNING

B<THIS IS AN EARLY VERSION!> Basically I have not decided 100% that the API
will remain as-is (though it likely will not change much). I am also embarrased
to admit that this code is very poorly tested (Yes, this is more embarrasing
considering I wrote L<Fennec>).

=head1 SYNOPSYS

=head2 TEMPLATE PACKAGE

    package My::Templates;
    use strict;
    use warnings;

    use DSL::HTML;

    use base 'Exporter'; # You can export your templates

    our @EXPORT = qw/ulist list_pair/;

    template ulist {
        # $self is auto-shifted for you and is an instance of
        # DSL::HTML::Rendering.
        my @items = @_;

        css 'ulist.css';

        tag ul(class => 'my_ulist') {
            for my $item (@items) {
                tag li { $item }
            }
        }
    }

    template list_pair {
        my ($items_a, $items_b) = @_;
        include ulist => @$items_a; # Using the ulist template above
        include ulist => @$items_b; # " "
    }

    1;

Now to use it:

    # This will import the 'build_template' function, as well as all the
    # templates defined by the package. You can request only specific templates
    # by passing them as arguments to the use statement.
    use My::Templates;

    my $html = build_template list_pair => (
        [qw/red green blue/],
        [qw/one two three/],
    );

    print $html;

Should give us:

    <html>
        <head>
            <link type="text/css" rel="stylesheet" href="ulist.css" />
        </head>

        <body>
            <ul class="my_ulist">
                <li>
                    red
                </li>
                <li>
                    green
                </li>
                <li>
                    blue
                </li>
            </ul>
            <ul class="my_ulist">
                <li>
                    one
                </li>
                <li>
                    two
                </li>
                <li>
                    three
                </li>
            </ul>
        </body>
    </html>


=head2 TEMPLATE OBJECT

If you do not like defining templates as package meta-data you can use them in
a less-meta form:

B<Note:> You could also skip the fancy syntax

    use strict;
    use warnings;

    use DSL::HTML;

    my $ulist = template ulist {
        # $self is auto-shifted for you and is an instance of
        # DSL::HTML::Rendering.
        my @items = @_;

        css 'ulist.css';

        tag ul(class => 'my_ulist') {
            for my $item (@items) {
                tag li { $item }
            }
        }
    }

    my $list_pair = template list_pair {
        my ($items_a, $items_b) = @_;
        $ulist->include( @$items_a ); # Using the ulist template above
        $ulist->include( @$items_b ); # " "

        # Alternatively you could do:
        # include $ulist => ...;
        # the 'include' keyword works with at emplate object as an argument
    }

    my $html = $list_pair->compile(
        [qw/red green blue/],
        [qw/one two three/],
    );

    # You could also do:
    # build_template $list_pair => (...);

    print $html;

Should give us:

    <html>
        <head>
            <link type="text/css" rel="stylesheet" href="ulist.css" />
        </head>

        <body>
            <ul class="my_ulist">
                <li>
                    red
                </li>
                <li>
                    green
                </li>
                <li>
                    blue
                </li>
            </ul>
            <ul class="my_ulist">
                <li>
                    one
                </li>
                <li>
                    two
                </li>
                <li>
                    three
                </li>
            </ul>
        </body>
    </html>

=head1 GUTS

This package works via a template stack system. When you build a template a
rendering object is pushed onto a stack, the codeblock you provided is then
executed. Any tags defined at this point get added to the rendering object at
the top of the stack.

When a tag is defined it is pushed to the top of the stack, then the codelbock
for it is run. In this way you can create a nested HTML structure. After all
the nested codeblocks are executed, the html content is built from the tree.

Because of this stack system you can also write helper objects or functions
which themselves call tag, or any other export provided by this package, so
long as those helpers are called (no matter how indirectly) from within a
template codeblock you are fine.

=head1 EXPORTS

=over 4

=item import()

When you C<use> L<DSL::HTML> it will inject a method called C<import> into your
package. This is done so that anyone that loads your package via C<use> will
gain all your templates, as well as the C<build_template> function.

B<Note:> This will cause a conflict if you use it in any module that uses
L<Exporter>, L<Exporter::Declare>, or similar exporter modules. To prevent this
you can tell L<DSL::HTML> not to inject C<import()> at use time, either by
rejecting it specifically, or by specifying with functions you do want:

Outright rejection:

    use DSL::HTML '-default', '!import';

Just what you want:

    use DSL::HTML qw/template tag css js build_template get_template/;

If you do either of these then loading your template package will NOT make your
templates available to the package loading it, but you can get them via:

    use Your::Package;
    my $tmp = Your::Package->get_template('the_template');
    my $html = $tmp->build( ... );

=item template NAME(%PARAMS) { ... }

=item template NAME { ... }

=item $t = template NAME(%PARAMS) { ... }

=item $t = template NAME { ... }

Define a template. If the return value is ignored the template will be inserted
into the current package metadata. If you capture the return value then nothing
is stored in the meta-data.

Parameters are optional, currently the only used parameter is 'indent' which
can be set to "\t" or a number of spaces.

An L<DSL::HTML::Template> object is created.

=item tag NAME(%ATTRIBUTES) { ... }

=item tag NAME { ... }

Define a tag. Never returns anything. All attributes are optional, any may be
specified. The 'class' attribute is handled specially so that classes can be
dynamically added and removed using C<add_class()> and C<remove_class()>.

Calls to tag must be made within a template, they will not work anywhere else
(though because of the stack you may call tag() within a function or method
that you call within a template).

B<Note:> the 'head' and 'body' tags have special handling. Every time you call
C<tag head {...}> within a template you get the same tag object. The same
behavior applies to the body tag.

You can and should nest calls to tag, this allows you to create a tag tree.

    template foo {
        tag parent {
            tag child {
                ...
            }
        }
    }

Under the hood an L<DSL::HTML::Tag> is created.

=item text "...";

Define a text element in the current template/tag.

Under the hood an L<DSL::HTML::Text> is created.

=item css "path/to/file.css";

Append a css file to the header. This can be called multiple times, each path
will only be included once.

=item js "path/to/file.js";

Append a js file to the header. This can be called multiple times, each path
will only be included once.

=item attr name => 'val', ...;

Set specific attributes in the current tag.

=item attr { name => 'val' };

Reset all attributes in the current tag to those provided in the hashref.

=item add_class 'name';

Add a class to the current tag.

=item del_class 'name';

Remove a class from the current tag.

=item $html = build_template $TEMPLATE => @ARGS

=item $html = build_template $TEMPLATE, @ARGS

=item $html = build_template $TEMPLATE

Build html from a template given specific arguments (optional). Template may be
a template name which will can be found in the current package meta-data, or it
can be an L<DSL::HTML::Template> object.

=item include $TEMPLATE => @ARGS

=item include $TEMPLATE, @ARGS

=item include $TEMPLATE

Nest the result of building another template within the current one.

=item $tmp = get_template($name)

=item $tmp = PACKAGE->get_template($name)

=item $tmp = $INSTANCE->get_template($name)

Get a template. When used as a function it will find the template in the
current package meta-data. When called as a method on a class or instance it
will find the template in the metadata for that package.

=back

=head1 WHOAH! NICE SYNTAX

The syntax is provided via L<Exporter::Declare> which uses L<Devel::Declare>.

=head1 SEE ALSO

=over 4

=item HTML::Declare

L<HTML::Declare> seems to be a similar idea, however I dislike the syntax and
some other oddities.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2013 Chad Granum

DSL-HTML is free software; Standard perl license (GPL and Artistic).

DSL-HTML is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.
