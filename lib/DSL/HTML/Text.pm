package DSL::HTML::Text;
use strict;
use warnings;

sub new {
    my $class = shift;
    my @value = @_;

    return bless \@value, $class;
}

sub as_html {
    my $self = shift;
    my ( $level, $indent ) = @_;
    my $lead = ($indent eq "\t" ? "\t" : ' ' x $indent ) x $level;
    return join "" => map { "${lead}$_\n" } @$self;
}

1;

__END__

=head1 NAME

DSL::HTML::Text - Used internally by L<DSL::HTML>

=head1 NOTES

You should never need to construct this yourself.

=head1 METHODS

=over 4

=item as_html

Returns the content of this text element.

=back

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2013 Chad Granum

DSL-HTML is free software; Standard perl license (GPL and Artistic).

DSL-HTML is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.
