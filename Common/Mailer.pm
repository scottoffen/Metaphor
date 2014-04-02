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
	# $ENV{'HTTP_HOST'} = "www.domain.com" unless (defined $ENV{'HTTP_HOST'});
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Net::SMTP;
	use MIME::Base64;
	use Mail::RFC822::Address qw(valid);
	use Time::Local;
	use Common::Config;
	use Common::Logging;
	use Common::Storage qw(GetFileAsBase64 GetFileName);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT = qw(SendText SendEmail);
	our $MAILER = GetConfig()->{'mailer'} || { "config" => {}, "lists" => {} };
	our $CONFIG = $MAILER->{"config"}     || {};
	our $LISTS  = $MAILER->{"lists"}      || {};
	our $KEY    = '_SMTP';

	our $DEF    = do
	{
		my $def = undef;
		if (exists $CONFIG->{default})
		{
			$def = $CONFIG->{default};
			delete $CONFIG->{default};
		}

		$def;
	};

	our $HOST   = do
	{
		my @httphost = split(/\./, $1) if ($ENV{'HTTP_HOST'} =~ /^(.+)$/i);
		join(".", ("mail", $httphost[-2], $httphost[-1]));
	};

	$ENV{$KEY}  = {};
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Module Cleanup                                                                   #
#----------------------------------------------------------------------------------#
END
{
	foreach my $key (keys %{$ENV{$KEY}})
	{
		my $smtp = $ENV{$KEY}->{$key}->{smtp};
		$smtp->quit() if (ref $smtp eq "Net::SMTP");
	}
}
#----------------------------------------------------------------------------------#


###############################|     AddAccount     |###############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub AddAccount
{
	my ($class, $params) = @_;

	if (($params) && (ref $params eq 'HASH'))
	{
		my $label = (exists $params->{label}) ? $params->{label} : (exists $params->{username}) ? $params->{username} : 'unlabeled';

		if (VerifySMTPParams($label, $params))
		{
			$CONFIG->{$label} = $params;
			return $label;
		}
	}

	return undef;
}
#########################################||#########################################



#################################|     Attach     |#################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Attach
{
	my ($files)     = @_;
	my $attachments = {};

	if (ref $files eq 'HASH')
	{
		foreach my $file (keys %$files)
		{
			next unless ((-e $file) && (!(-d $file)));

			my $attachment =
			{
				'disposition' => ($files->{$file} !~ /^1$/) ? 'attachment' : 'inline',
				'date'        => CurrentDate((stat($file))[9]),
				'filename'    => GetFileName($file),
				'content'     => GetFileAsBase64($file)
			};

			$attachment->{contentid} = $attachment->{filename} . '.' . $$ . '.' . time() . '@' . $ENV{'HTTP_HOST'};
			$attachments->{$attachment->{contentid}} = $attachment;
		}
	}

	return $attachments;
}
#########################################||#########################################



################################|     Boundary     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Boundary
{
	my $length     = ((@_) && ($_[0] =~ /^\d{1,2}$/)) ? shift : 50;
	my $result     = "=_NextPart_";
	my $characters = ".=_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

	until (length $result == $length)
	{
		$result .= substr($characters, (int(rand length($characters)) + 1), 1);
	}

	return $result;
}
#########################################||#########################################



###############################|     BuildEmail     |###############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub BuildEmail
{
	my ($params) = @_;
	my $email    = '';
	my $boundary = undef;

	#----------------------------------------------------------------------------------#
	# Email includes attachments                                                       #
	#----------------------------------------------------------------------------------#
	# if ()
	# {

	# }
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Email has html (text optional)                                                   #
	#----------------------------------------------------------------------------------#
	# elsif ()
	# {

	# }
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Text only or no body                                                             #
	#----------------------------------------------------------------------------------#
	# else
	# {

	# }
	#----------------------------------------------------------------------------------#



	return $email;
}
#########################################||#########################################



#################################|     Connect     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Connect
{
	my ($label, $params) = @_;

	if (($label) && ($params))
	{
		my $smtp = 1; #new Net::SMTP($params->{mailhost});
		if ($smtp)
		{
			if (1) #($smtp->auth($params->{username}, decode_base64($params->{password})))
			{
				$params->{smtp}      = $smtp;
				$ENV{$KEY}->{$label} = $params;
				return $ENV{$KEY}->{$label};
			}
			else
			{
				$smtp->quit();
				WARN(join(" : ", ("SMTP authentication failed", $params->{address}, $params->{username}, $params->{mailhost})));
			}
		}
		else
		{
			WARN("Unable to establish an smtp connection to " . $params->{mailhost});
		}
	}

	return undef;
}
#########################################||#########################################



##############################|     CurrentDate     |###############################
# Private                                                                          #
# 0 : Optional, unix timestamp                                                     #
#----------------------------------------------------------------------------------#
sub CurrentDate
{
	my $time = ((scalar @_ > 0) && ($_[0] =~ /^\d+$/)) ? shift : time();

	my @localtime = localtime($time);
	my @timeparts = split(/ /, localtime($time));

	my $timezone = ((abs(timegm(@localtime) - timelocal(@localtime))) / (60 * 60)) * 100;
	$timezone    = '0' . $timezone if (length $timezone < 4);
	$timezone    = '-' . $timezone if (timelocal(@localtime) > timegm(@localtime));

	return "$timeparts[0], $timeparts[2] $timeparts[1] $timeparts[4] $timeparts[3] $timezone";
}
#########################################||#########################################



##############################|     GetConnection     |#############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetConnection
{
	my ($params) = @_;

	if ($params)
	{
		if ((ref $params) && (ref $params eq 'HASH'))
		{
			my $label = Common::Mailer::AddAccount($params);
			if ($label)
			{
				return Connect($label, $CONFIG->{$label});
			}
		}
		else
		{
			if (exists $ENV{$KEY}->{$params})
			{
				return $ENV{$KEY}->{$params};
			}
			elsif ((exists $CONFIG->{$params}) && (VerifySMTPParams($params, $CONFIG->{$params})))
			{
				return Connect($params, $CONFIG->{$params});
			}
		}
	}
	elsif (defined $DEF)
	{
		print "\nno params: $DEF\n";
		# if (exists $ENV{$KEY}->{$DEF})
		# {
		# 	return $ENV{$KEY}->{$DEF};
		# }
		# elsif ((exists $CONFIG->{$DEF}) && (VerifySMTPParams($CONFIG->{$DEF})))
		# {
		# 	return Connect($DEF, $CONFIG->{$DEF});
		# }
	}

	return undef;
}
#########################################||#########################################



##############################|     GetRecipients     |#############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetRecipients
{
	my @lists = @_;
	my (%recipients, @recipients);

	foreach my $list (@lists)
	{
		next unless (ref $list eq 'HASH');
		$recipients{$_} = 1 foreach (keys %$list);
	}

	push(@recipients, $_) foreach (keys %recipients);

	return (wantarray) ? @recipients : \@recipients;
}
#########################################||#########################################



################################|     SendEmail     |###############################
# Exported                                                                         #
# 0 : Parameter Hashref                                                            #
#     {                                                                            #
#	    from    => an account lable or hashref of connection parameters, defaults  #
#                  to the configured default account                               #
#       to      => a list lable (notify) or hashref of address:name values         #
#       cc      => optional : same as to field                                     #
#       bcc     => optional : same as to field                                     #
#       subject => optional : defaults to [no subject]                             #
#       data    => A hashref with one or more of the following:                    #
#       {                                                                          #
# 	      text  => the plain text part of the email                                #
# 	      html  => the html part of the email                                      #
# 	      files => an array of files (base64 encoded) or file paths to attach      #
#       }                                                                          #
#       headers => optional hashref of desired headers                             #
#     }                                                                            #
#----------------------------------------------------------------------------------#
sub SendEmail
{
	my $params  = VerifySendParams($_[0]);
	my $account = ($params) ? $params->{account} : undef;

	if (($params) && ($account))
	{
		#----------------------------------------------------------------------------------#
		# Email parameters are valid, account assumptions can be made                      #
		#----------------------------------------------------------------------------------#
		TRACE("Email parameters valid, account " . $account->{username} . " found and connected.");
		$params->{from} = '"' . $account->{name} . '" <' . $account->{address} . '>';
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Complete setting up the email to be sent                                         #
		#----------------------------------------------------------------------------------#
		TRACE("Building email...");
		my $email = BuildEmail($params);
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Initiate sending email                                                           #
		#----------------------------------------------------------------------------------#
		TRACE("Initiate sending email from " . $account->{username} . ".");
		# $account->{smtp}->mail($account->{username});
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Notify the server that the current message should be sent to all recipients      #
		#----------------------------------------------------------------------------------#
		TRACE("Notify the server that the current message should be sent to all recipients");
		# $account->{smtp}->recipient(@{$params->{recipients}}, { SkipBad => 1 });
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Initiate the sending of the data from the current message.                       #
		#----------------------------------------------------------------------------------#
		if (1) #($account->{smtp}->data())
		{
			TRACE("Sending email: $email");
			# $account->{smtp}->datasend($email);
			# $account->{smtp}->dataend();
			return 1;
		}
		else
		{
			WARN("Unable to send email on account " . $account->{label});
		}
		#----------------------------------------------------------------------------------#
	}
	else
	{
		WARN("Invalid parameters or unable to locate account.");
	}

	return undef;
}
#########################################||#########################################



###############################|     SetDefault     |###############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub SetDefault
{
	my $class = shift;
	my $value = ((scalar @_ > 0) && (defined $_[0])) ? shift : undef;

	if ((defined $value) && (exists $CONFIG->{$value}))
	{
		$DEF = $value;
	}
}
#########################################||#########################################



#############################|     VerifyAddress     |##############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub VerifyAddress
{
	my ($param) = @_;
	my $result  = {};

	if ($param)
	{
		#----------------------------------------------------------------------------------#
		# Normalize : Parameter could be an email address, a group label, or a hashref     #
		#----------------------------------------------------------------------------------#
		my $addresses = do
		{
			my $retval = {};

			if (ref $param eq 'HASH')
			{
				$retval = $param;
			}
			elsif (!ref $param)
			{
				if (exists $LISTS->{$param})
				{
					$retval = $LISTS->{$param};
				}
				elsif (valid $param)
				{
					$retval = { $param => $param };
				}
				elsif ($param =~ /\"(.+)\" <(.+)>/i)
				{
					$retval = { $2 => $1 };
				}
			}

			$retval;
		};
		#----------------------------------------------------------------------------------#


		foreach my $key (keys %$addresses)
		{
			my $val = $addresses->{$key};

			if (valid($key))
			{
				$result->{$key} = $val;
			}
			elsif (valid($val))
			{
				$result->{$val} = $key;
			}
		}
	}

	return $result;
}
#########################################||#########################################



############################|     VerifySendParams     |############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub VerifySendParams
{
	my ($params) = @_;

	#----------------------------------------------------------------------------------#
	# Normalize hashkeys and get account                                               #
	#----------------------------------------------------------------------------------#
	my $account;
	{
		if (ref $params eq 'HASH')
		{
			my %params = map { lc $_ => $params->{$_} } keys %$params;
			%$params   = map { $_ => $params{$_} } (keys %params);
			$account = (defined $params->{from}) ? GetConnection($params->{from}) : undef;
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Account must be valid before bothering to parse anything else                    #
	#----------------------------------------------------------------------------------#
	if ($account)
	{
		my $headers  = { 'X-Auto-Response-Suppress' => 'DR, RN, NRN, OOF, AutoReply', 'Mime-Version' => '1.0', 'Date' => CurrentDate() };

		#----------------------------------------------------------------------------------#
		# Default subject, normalize to/cc/bcc                                             #
		#----------------------------------------------------------------------------------#
		$params->{subject}    = '[no subject]' unless (defined $params->{subject});
		$params->{to}         = VerifyAddress($params->{to});
		$params->{cc}         = VerifyAddress($params->{cc});
		$params->{bcc}        = VerifyAddress($params->{bcc});
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Valid if there is at least one recipient                                         #
		#----------------------------------------------------------------------------------#
		my $recipients = GetRecipients($params->{to}, $params->{cc}, $params->{bcc});
		if (scalar @$recipients > 0)
		{
			#----------------------------------------------------------------------------------#
			# Add headers (overwrite as needed)                                                #
			#----------------------------------------------------------------------------------#
			$headers->{'From'}    = '"' . $account->{name} . '" <' . $account->{address} . '>';
			$headers->{'Subject'} = '?=utf-8?B?' . encode_base64($params->{subject}) . '?=';
			$headers->{'To'}      = join(', ', map { "\"" . $params->{to}->{$_} . "\" <$_>" } keys %{$params->{to}});
			$headers->{'CC'}      = join(', ', map { "\"" . $params->{cc}->{$_} . "\" <$_>" } keys %{$params->{cc}});
			#----------------------------------------------------------------------------------#

			my $verified = { account => $account, recipients => $recipients, headers => $headers };
			return $verified;
		}
		#----------------------------------------------------------------------------------#
	}
	#----------------------------------------------------------------------------------#

	return undef;
}
#########################################||#########################################



############################|     VerifySMTPParams     |############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub VerifySMTPParams
{
	my ($label, $params) = @_;

	#----------------------------------------------------------------------------------#
	# Verify required parameters have been provided                                    #
	#----------------------------------------------------------------------------------#
	{
		my @required = qw(mailhost name address username password);
		my $missing  = 0;
		my @missing  = ();

		foreach my $key (@required)
		{
			unless ((exists $params->{$key}) && (defined $params->{$key}))
			{
				push (@missing, $key);
				$missing++;
			}
		}

		if ($missing > 0)
		{
			ERROR("Unable to connect to smtp $label : missing $missing configuration parameters (" . join(', ', @missing) . ").");
			return undef;
		}

		return 1;
	}
	#----------------------------------------------------------------------------------#
}
#########################################||#########################################



1;
