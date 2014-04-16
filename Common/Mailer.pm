package Common::Mailer;
our $VERSION = '1.0.0.0';

#########################################||#########################################
#                                                                                  #
# Common::Mailer                                                                   #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Module Initialization                                                            #
#----------------------------------------------------------------------------------#
BEGIN
{
	# If you are developing locally and running from the command line, define this
	# $ENV{'HTTP_HOST'} = "www.robotscott.com" unless (defined $ENV{'HTTP_HOST'});
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Net::SMTP;
	# use MIME::Base64;
	# use Mail::RFC822::Address qw(valid);
	# use Time::Local;
	use Common::Config;
	use Common::Logging;
	# use Common::Storage qw(GetFileAsBase64 GetFileName);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT = qw(SendText SendEmail);

	my $SMTP_HOST = 'mail.host.com:port';

	my $parameters = {
		Username => 'user@domain.com',
		Password => 'password',
		From     => 'user@domain.com',
		To       => 'address@domain.com',
		Subject  => 'Test Email',
		Message  => 'This is a test email.'
	};

	my $result = (SendEmail($parameters)) ? 'Test Passed' : 'Test Failed';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Module Cleanup                                                                   #
#----------------------------------------------------------------------------------#
END
{

}
#----------------------------------------------------------------------------------#


################################|     SendText     |################################
sub SendText
{
	
}
#########################################||#########################################



################################|     SendEmail     |###############################
sub SendEmail
{
	my $parameters = shift;

	#
	# Open a SMTP session
	#
	my $smtp = new Net::SMTP($SMTP_HOST, Timeout => 60, Debug => 1);

	if (!defined($smtp) || !($smtp))
	{
		print "SMTP ERROR: Unable to open smtp session.\n";
		return 0;
	}

	#
	# Authentication
	#
	if (!($smtp->auth($parameters->{Username}, $parameters->{Password})))
	{
		print "\nAuthentication failed using username [" . $parameters->{Username} . "] and password [" . $parameters->{Password} . "] : $!\n";
		return 0;
	}

	#
	# Pass the 'from' email address, exit if error
	#
	if (! ($smtp->mail( $parameters->{From} ) ) )
	{
		print "Can't send from " . $parameters->{From} . "\n";
		return 0;
	}

	#
	# Pass the recipient address
	#
	if (! ($smtp->recipient( $parameters->{To} ) ) )
	{
		print "Can't send to " . $parameters->{To} . "\n";
		return 0;
	}

	#
	# Send the message
	#
	my $msg = "To: " . $parameters->{To} . "\nFrom: " . $parameters->{From} . "\nSubject: " . $parameters->{Subject} . "\nContent-type: text/plain\n\n" . $parameters->{Message};

	if (! ($smtp->data( $msg ) ) )
	{
		print "Data refused.\n";
		return 0;
	}

	$smtp->quit;
	return 1;
}
#########################################||#########################################






1;
