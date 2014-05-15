#!C:\lang\perl\bin\perl.exe
#!/usr/bin/perl
use strict;
use warnings;

#----------------------------------------------------------------------------------#
# Initialization                                                                   #
#----------------------------------------------------------------------------------#
BEGIN
{
	$| = 1;
	unshift(@INC, 'C:/source/github/common-perl');
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# External Dependencies                                                            #
#----------------------------------------------------------------------------------#
	use Common::Logging;
	use Common::Util;
	use Example::User;
	use Common::REST;
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Service Configuration                                                            #
#----------------------------------------------------------------------------------#
	# Get current authenticated session
	# my $session = [package]::Session->GetCurrent();

	# Create global regex values
	my $guid = '[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}';

	# Send log output to a file
	# Common::Logging->StartLog({ file => "service.txt", level => 'DEBUG' });

	# Send log output to the console
	# Common::Logging->ConsoleOn();
#----------------------------------------------------------------------------------#


#########################################||#########################################
#                                                                                  #
# The eval block will attempt every HANDLER combinations defined until it succeeds #
# and exits or it barfs and/or produces an error.                                  #
#                                                                                  #
#########################################||#########################################
eval
{
	#----------------------------------------------------------------------------------#
	# Check Authenticated                                                              #
	#----------------------------------------------------------------------------------#
	# unless (ref $session)
	# {
	# 	barf('401', '<!doctype html><html><head><title>401 Not Authenticated</title></head><body><h1>Not Authenticated</h1></body></html>');
	# }
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# GET : Return an existing user                                                    #
	#----------------------------------------------------------------------------------#
	Route { REQUEST_METHOD => qr{^(get|head)$}i, PATH_INFO => qr{^/user/($guid)$}i } =>
	sub
	{
		my ($request, $content) = @_;

		my $user = new Example::User($request->{PATH_INFO});

		if ($user)
		{
		 	SetContent({ user => $user->Simplify() }, 'json');
		}
		else
		{
			SetContent({ error => "Unable to locate user (" . $request->{PATH_INFO} . ")" }, 'json');
		}
	};
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# POST : Create a new user                                                         #
	#----------------------------------------------------------------------------------#
	Route { REQUEST_METHOD => qr{^post$}i, PATH_INFO => qr{^/user$}i } =>
	sub
	{
		#--> TODO
		my ($request, $content) = @_;
		SetContent({ request => $request, content => $content }, 'json');
	};
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# PUT : Update existing user                                                       #
	#----------------------------------------------------------------------------------#
	Route { REQUEST_METHOD => qr{^put$}i, PATH_INFO => qr{^/user/($guid)$}i } =>
	sub
	{
		#--> TODO
		my ($request, $content) = @_;
		SetContent({ request => $request, content => $content }, 'json');
	};
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# DELETE : Delete a user                                                           #
	#----------------------------------------------------------------------------------#
	Route { REQUEST_METHOD => qr{^delete$}i, PATH_INFO => qr{^/user/($guid)$}i } =>
	sub
	{
		my ($request, $content) = @_;

		my $user = new Example::User($request->{PATH_INFO});

		if ($user)
		{
			my $result = ($user->Delete()) ? 'true' : 'false';
		 	SetContent({ deleted => $result }, 'json');
		}
		else
		{
			SetContent({ error => "Unable to locate user (" . $request->{PATH_INFO} . ")" }, 'json');
		}
	};
	#----------------------------------------------------------------------------------#
};
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Swagger Resourse Listing : Description                                           #
#----------------------------------------------------------------------------------#
=begin description
Swagger resource description goes here.
=end description
=cut
#----------------------------------------------------------------------------------#