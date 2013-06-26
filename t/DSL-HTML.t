use strict;
use warnings;
use Fennec::Declare class => 'DSL::HTML';

BEGIN { use_ok $CLASS, '-default', '!import' }

describe exports {
    return unless $self->can_ok( qw{
        template
        tag
        text
        css
        js
        attr
        add_class
        del_class
        build_template
        get_template
        include
    });

    template test {
        isa_ok( $self, 'DSL::HTML::Rendering' );
        my $count = shift;

        tag div { 'test' }
        css 'a.css';
        css 'b.css';
        css 'b.css'; # duplicate

        if ( $count ) {
            tag head {
                tag title { 'foo' }
            }
        }

        # Ensure that there is only ever 1 head tag
        unless ( $count ) {
            tag head {
                tag meta { 'bar' }
            }
        }

        # Not necessary, body is already top of the stack
        tag body {
            tag div { 'nested body' }

            # Despite the nesting these still go to the head
            js 'a.js';
            js 'b.js';
            js 'b.js'; #duplicate
        }

        tag div(id => 'bar', class => 'a b c' ) {
            add_class 'e';
            del_class 'b';
            attr style => 'display: none;';
        }

        tag div(id => 'go_away') {
            attr { foo => 'bar' };
        }

        text "simple text";

        # Nested template call
        include test => $count - 1 if $count;
    }

    tests access {
        ok( $self->get_template( 'test' ), "got the template via method" );
        ok( get_template( 'test' ), "got the template via function" );
    }

    tests template {
        my $html = build_template test => 1;
        is( $html, <<'        EOT', "Got expected html" );
<html>
    <head>
        <title>
            foo
        </title>
        <meta>
            bar
        </meta>
        <link href="a.css" rel="stylesheet" type="text/css" />
        <link href="b.css" rel="stylesheet" type="text/css" />
        <script src="a.js"></script>
        <script src="b.js"></script>
    </head>

    <body>
        <div>
            test
        </div>
        <div>
            nested body
        </div>
        <div class="a c e" id="bar" style="display: none;" />
        <div foo="bar" />
        simple text
        <div>
            test
        </div>
        <div class="a c e" id="bar" style="display: none;" />
        <div foo="bar" />
        simple text
        <div>
            nested body
        </div>
    </body>
</html>
        EOT
    }
}

done_testing;
