#!/usr/bin/perl -T
use strict;
use warnings;

#----------------------------------------------------------------------------------#
# Initialization                                                                   #
#----------------------------------------------------------------------------------#
BEGIN
{
    $| = 1;
    push(@INC, '/home/path/to/modules');
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Configuration                                                                    #
#----------------------------------------------------------------------------------#
use Metaphor::REST;
#----------------------------------------------------------------------------------#


#########################################||#########################################
eval
{
    Route { REQUEST_METHOD => qr{^$}i, PATH_INFO => qr{^} } => sub
    {
        my ($captured, $content) = @_;

        Respond
        {
        	'-type' => 'json',
        	'content' => { captured => $captured, content => $content }
        };
    };
}
#########################################||#########################################

__END__

POD is not required here, but it can be used to generate API documentation

=pod

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Methods

=over 12

=item C<method(PARAMS)>

=back

=head1 BUGS

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT

=head1 AVAILABILITY

=head1 AUTHOR

=head1 SEE ALSO

=cut
