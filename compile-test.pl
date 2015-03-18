#!/usr/bin/perl
use strict;
use warnings;

print "Content-type: text/html\n\n" if (exists $ENV{HTTP_HOST});

#----------------------------------------------------------------------------------#
# Initialization                                                                   #
#----------------------------------------------------------------------------------#
BEGIN
{
	$| = 1;
	push(@INC, 'c:/source/github/metaphor');
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# External Dependencies                                                            #
#----------------------------------------------------------------------------------#
	print "Modules Loading...";

	use Metaphor::BaseX;
	use Metaphor::Config;
	use Metaphor::Database;
	use Metaphor::Encryption;
	use Metaphor::Logging;
	use Metaphor::Mailer;
	use Metaphor::REST;
	use Metaphor::Scripting;
	use Metaphor::Simplify;
	use Metaphor::Storage;
	use Metaphor::Tripcode;
	use Metaphor::Util;

	print "Loaded\n";
#----------------------------------------------------------------------------------#

exit;