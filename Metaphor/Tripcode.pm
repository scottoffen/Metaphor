package Metaphor::Tripcode;

#########################################||#########################################
#                                                                                  #
# Metaphor::Tripcode                                                               #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Encode qw(encode);
	use Metaphor::Util qw(Declassify);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $VERSION = '1.0.0';
	our @EXPORT  = qw(GetTripcode);

	our $REPLACE =
	{
		'58' => 'A',
		'59' => 'B',
		'60' => 'C',
		'61' => 'D',
		'62' => 'E',
		'63' => 'F',
		'64' => 'G',
		'91' => 'a',
		'93' => 'b',
		'94' => 'c',
		'95' => 'd',
		'96' => 'e'
	};
#----------------------------------------------------------------------------------#


##############################|     GetTripcode     |###############################
# Exported                                                                         #
#                                                                                  #
# Implements a basic tripcode algorithm for pseudo-registration systems. Input is  #
# expected to be in the format of 'name#password', returns 'name#tripcode'.        #
#                                                                                  #
# 1. Split username and password on the first occurence of the '#'.                #
#                                                                                  #
# 2. Generate salt by taking the second and third characters of the string         #
#    produced after appending the name part with 'H..'. [1]                        #
#                                                                                  #
# 3. Replace any character in password part not between ASCII 46 (.) and 122 (z)   #
#    inclusive with a period (.).                                                  #
#                                                                                  #
# 4. Replace any of the characters in the set :;<=>?@[]^_` found in the password   #
#    part with the corresponding character from ABCDEFGabcdef.                     #
#                                                                                  #
# 5. Call the crypt() function with the input and salt.                            #
#                                                                                  #
# 6. Return the last 10 characters. (compressional data harvest)                   #
#                                                                                  #
# source: http://en.wikipedia.org/wiki/File:Tripcode_generation_diagram.svg        #
#                                                                                  #
# [1] By deriving salt from the username instead of the password, we decrease the  #
#     statistical likelyhood that two people who use the same password will have   #
#     generated the same tripcode, and that two identical tripcodes will have been #
#     resultant of the same password.                                              #
#----------------------------------------------------------------------------------#
sub GetTripcode
{
	my ($input, $seperator) = Declassify(\@_, __PACKAGE__);
	if ($input =~ /^(.{1,})#(.{1,})$/)
	{
		my ($username, $password) = ($1, $2);
		$seperator = '!' unless (length $seperator > 0);

		my $salt     = substr(($username . "H.."), 1,2);
		my @password = split('', encode("shiftjis", $password));
		my $chars    = scalar @password;

		for (my $i = 0; $i < $chars; $i += 1)
		{
			my $char  = $password[$i];
			my $ascii = ord($char);

			if (($ascii > 122) || ($ascii < 46))
			{
				$password[$i] = ".";
			}
			elsif (exists $REPLACE->{$ascii})
			{
				$password[$i] = $REPLACE->{$ascii}
			}
		}

		return "$username$seperator" . (substr(crypt(join('', @password), $salt), -10));
	}

	return;
}
#########################################||#########################################



##############################|     GetTripPhrase     |#############################
#                                                                                  #
#----------------------------------------------------------------------------------#
sub GetTripPhrase
{
	# TODO:
	# http://worrydream.com/tripphrase/
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Metaphor::Tripcode - Implements a basic tripcode algorithm for pseudo-registration systems.

=head1 SYNOPSIS

    use Metaphor::Tripcode; # exports GetTripcode by default

    my $tripcode = GetTripcode('name#password');
    print $tripcode;

    # output:
    # name!zwK2bfx.2U

=head1 DESCRIPTION

Tripcodes can help verify a user's identity to others, and are a type of pseudo-registration. To use a tripcode, append a name (e.g., username or real name) with a hash mark ("#") followed by a word or short phrase (e.g. "name#password"). A hash unique to that particular word or phrase will be generated. The previous example would return "name!zwK2bfx.2U".

Tripcode are a one-way encryption, and this module supplies no method to decrypt them.

B<NOTE: Tripcodes are not secure, and can be cracked with relative ease.  This module does not support "secure" tripcodes.>

=head2 Algorithm

The algorithm used to generate the tripcode is outlined below, and is a variation on the one described on L<wikipedia|http://en.wikipedia.org/wiki/File:Tripcode_generation_diagram.svg> here.

1. Split username and password on the first occurrence of the '#'.

2. Generate salt by taking the second and third characters of the string produced after appending the name part with 'H..'. [1]

3. Convert password part to ShiftJIS.

4. Replace any character in password part not between ASCII 46 (.) and 122 (z) inclusive with a period (.).

5. Replace any of the characters in the set :;<=>?@[]^_` found in the password part with the corresponding character from the set ABCDEFGabcdef.

6. Call the crypt() function with the input and salt.

7. Return the last 10 characters of the output of crypt (compressional data harvest).

[1] By deriving salt from the name instead of the password, we decrease the statistical likelihood that two people who use the same password will have generated the same tripcode, and that two identical tripcodes will have been resultant of the same password.

=head2 Methods

Only public methods are documented.

=over 12

=item C<GetTripcode(NameAndPassword [, TripcodeSeperator])>

I<[Exported]>

The I<NameAndPassword> input string is expected to be in the format of 'name#password'.  Returns a string with the tripcode in the format of 'name!tripcode'.  Returns I<undef> if the input string cannot be parsed.

The default tripcode separator is the bang (!).  An alternate tripcode separator can be passed in as a second argument, in which case it will be used instead.

    use Metaphor::Tripcode;

    my $tripcode1 = GetTripcode('name#password');
    my $tripcode2 = GetTripcode('name#password', '%');
    print "$tripcode1\n$tripcode2";

    # output:
    # name!zwK2bfx.2U
    # name%zwK2bfx.2U

Use of an alternate tripcode separator does not impact the generation of the tripcode.

=back

=head1 TODO

Implement I<GetTripPhrase> method described L<here|http://worrydream.com/tripphrase/>.

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 SEE ALSO

Using L<Encode> to convert the password to L<Shift JIS|http://en.wikipedia.org/wiki/Shift_JIS>.

My algorithm is loosely based on this L<tripcode generation diagram|http://en.wikipedia.org/wiki/File:Tripcode_generation_diagram.svg> on wikipedia.

=head1 DEPENDENCIES

=over 1

=item * L<Metaphor::Util|http://https://github.com/scottoffen/common-perl/wiki/Metaphor::Util>

=back

=cut