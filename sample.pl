#!/usr/bin/perl
#!C:\lang\perl\bin\perl.exe
use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser);

#----------------------------------------------------------------------------------#
# Initialization                                                                   #
#----------------------------------------------------------------------------------#
BEGIN
{
	$| = 1;
	unshift(@INC, 'c:/source/github/metaphor');
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