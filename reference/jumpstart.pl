#!C:\lang\perl\bin\perl.exe
use strict;
use warnings;

#----------------------------------------------------------------------------------#
# Initialization                                                                   #
#----------------------------------------------------------------------------------#
BEGIN
{
	$| = 1;

	unshift(@INC, do
	{
		my @locations;
		foreach my $location ('C:/source/github/scottoffen/Common-Perl')
		{
			if (-d $location)
			{
				push (@locations, $location);
				last;
			}
		}

		@locations;
	});
}
#----------------------------------------------------------------------------------#

use Common::BaseX;
use Common::Config;
use Common::Database;
use Common::Logging;
use Common::Mailer;
use Common::REST;
use Common::Simplify;
use Common::Storage;
use Common::Swagger;
use Common::Tripcode;
use Common::Util;


print "\nDone\n";