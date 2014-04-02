package Common::Tripcode;
our $VERSION = '1.0.0.0';

#########################################||#########################################
#                                                                                  #
# Common::Tripcode                                                                 #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Encode qw(encode);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
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
	if ((scalar @_ > 0) && ($_[0] =~ /^(.{1,})#(.{1,})$/))
	{
		my ($username, $password) = ($1, $2);
		my $seperator = (($_[1]) && (length $_[1] > 0)) ? $_[1] : '!';

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

	return undef;
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