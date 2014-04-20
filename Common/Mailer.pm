package Common::Mailer;
our $VERSION = '1.0.0.0';

#########################################||#########################################
#                                                                                  #
# Common::Mailer                                                                   #
# � Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Module Initialization                                                            #
#----------------------------------------------------------------------------------#
BEGIN
{
	# If you are developing locally and running from the command line, define this
	$ENV{'HTTP_HOST'} = "www.robotscott.com:587" unless (defined $ENV{'HTTP_HOST'});
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Net::SMTP;
	use MIME::Base64;
	use Encode qw(encode);
	use Mail::RFC822::Address qw(valid);
	use Time::Local;
	use Common::Config;
	use Common::Logging;
	use Common::Storage qw(GetFileAsBase64 GetFileName);
	use Common::Util qw(RandomString TrimString);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT   = qw(SendText SendEmail);
	our $MAILER   = GetConfig()->{'mailer'} || { "accounts" => {}, "lists" => {} };
	our $LISTS    = $MAILER->{"lists"}      || {};
	our $KEY      = '_SMTP';
	our $ACCOUNTS = {};
	our $DEF      = undef;


	#----------------------------------------------------------------------------------#
	# Create default host                                                              #
	#----------------------------------------------------------------------------------#
	our $HOST   = do
	{
		my @httphost = split(/\./, $1) if ($ENV{'HTTP_HOST'} =~ /^(.+)$/i);
		join(".", ("mail", $httphost[-2], $httphost[-1]));
	};
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Pre-load accounts                                                                #
	#----------------------------------------------------------------------------------#
	{
		my $accounts = $MAILER->{"accounts"} || {};
		my $default  = undef;

		foreach my $key (keys %$accounts)
		{
			if ($key =~ /^default$/i)
			{
				$default = $accounts->{$key};
				next;
			}

			my $account = $accounts->{$key};
			$account->{label} = $key;
			Common::Mailer->AddAccount($account);
		}

		$DEF = $default if (($default) && (exists $ACCOUNTS->{$default}));
	}
	#----------------------------------------------------------------------------------#

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
		#----------------------------------------------------------------------------------#
		# Verify required parameters have been provided                                    #
		#----------------------------------------------------------------------------------#
		my $label = (exists $params->{label}) ? $params->{label} : (exists $params->{username}) ? $params->{username} : RandomString(10);
		$params->{mailhost} = $HOST unless (defined $params->{mailhost});
		{
			my $missing  = 0;
			my @missing  = ();

			foreach my $key ('mailhost', 'name', 'address', 'username', 'password')
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
			else
			{
				$params->{label}    = $label;
				$params->{password} = encode_base64($params->{password});
			}
		}
		#----------------------------------------------------------------------------------#

		$ACCOUNTS->{$label} = $params;
		return $label;
	}

	return undef;
}
#########################################||#########################################



#################################|     Attach     |#################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Attach
{
	my ($attach) = @_;

	if ((defined $attach) && (ref $attach eq 'HASH') && (defined $attach->{file}))
	{
		if ((-e $attach->{file}) && (!(-d $attach->{file})))
		{
			my $disposition = (defined $attach->{disposition}) ? $attach->{disposition} : 'attachment';
			my $filename    = (defined $attach->{filename}) ? $attach->{filename} : GetFileName($attach->{file});
			my $modified    = CurrentDate((stat($attach->{file}))[9]);

			my @attachment = ();
			push(@attachment, "Content-ID: <" . $attach->{id} . ">") if (defined $attach->{id});
			push(@attachment, "Content-Type: application/octet-stream; name=\"$filename\"");
			push(@attachment, "Content-Disposition: $disposition; filename=\"$filename\"; modification-date=$modified");
			push(@attachment, "Content-Transfer-Encoding: base64\n");
			push(@attachment, GetFileAsBase64($attach->{file}));

			return join("\n", @attachment);
		}
	}

	return undef;
}
#########################################||#########################################



################################|     Boundary     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Boundary
{
	my $length     = ((@_) && ($_[0] =~ /^\d{1,2}$/)) ? shift : 20;
	my $result     = "=_NextPart_";
	my $characters = ".=_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

	until (length $result == $length)
	{
		$result .= substr($characters, (int(rand length($characters)) + 1), 1);
	}

	return $result;
}
#########################################||#########################################



#################################|     Connect     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Connect
{
	my ($label) = @_;
	my $account = $ACCOUNTS->{$label};
	my $smtp    = new Net::SMTP($account->{mailhost});

	if ($smtp)
	{
		if ($smtp->auth($account->{username}, decode_base64($account->{password})))
		{
			$account->{smtp}     = $smtp;
			$ENV{$KEY}->{$label} = $account;
			return $ENV{$KEY}->{$label};
		}
		else
		{
			$smtp->quit();
			WARN(join(" : ", ("SMTP authentication failed", $account->{address}, $account->{username}, $account->{mailhost})));
		}
	}
	else
	{
		WARN("Unable to establish an smtp connection to " . $account->{mailhost});
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



############################|     FormattAddresses     |############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub FormattAddresses
{
	my ($list) = @_;
	return "" unless (($list) && (ref $list eq 'HASH'));
	return join("; ", map { $list->{$_} . " <$_>" } keys %$list);
}
#########################################||#########################################



##############################|     GetConnection     |#############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetConnection
{
	#----------------------------------------------------------------------------------#
	# Get the account label                                                            #
	#----------------------------------------------------------------------------------#
	my $label = undef;
	{
		my $val = $_[0] || $DEF;
		if (defined $val)
		{
			if ((ref $val eq 'HASH'))
			{
				$label = Common::Mailer->AddAccount($val)
			}
			elsif (exists $ACCOUNTS->{$val})
			{
				$label = $val;
			}
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Get the connection                                                               #
	#----------------------------------------------------------------------------------#
	if ($label)
	{
		if (exists $ENV{$KEY}->{$label})
		{
			return $ENV{$KEY}->{$label};
		}
		else
		{
			return Connect($label);
		}
	}
	#----------------------------------------------------------------------------------#

	return undef;
}
#########################################||#########################################



#############################|     MergeRecipients     |############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub MergeRecipients
{
	my $merged = {};

	foreach my $list (@_)
	{
		next unless (($list) && (ref $list eq 'HASH'));

		foreach my $key (keys %$list)
		{
			$merged->{$key} = 1;
		}
	}

	return (keys $merged);
}
#########################################||#########################################



################################|     SendEmail     |###############################
# Exported                                                                         #
# 0 : Parameter Hashref                                                            #
#     {                                                                            #
#	    from    => an account lable or hashref of connection parameters, defaults  #
#                  to the configured default account                               #
#       to      => a list lable or hashref of address:name values                  #
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
	my $params  = shift;
	my $account = GetConnection($params->{from});

	if ($account)
	{
		my ($headers, $content);

		my $defaults = { 'X-Auto-Response-Suppress' => 'DR, RN, NRN, OOF, AutoReply', 'Mime-Version' => '1.0', 'Date' => CurrentDate() };
		my $charset  = (defined $params->{charset}) ? $params->{charset} : "iso-8859-1";
		my $boundary = Boundary();

		#----------------------------------------------------------------------------------#
		# Generate headers                                                                 #
		#----------------------------------------------------------------------------------#
		$headers = ((defined $params->{headers}) && (ref $params->{headers} eq 'HASH')) ? $params->{headers} : {};
		foreach my $key (keys %$defaults)
		{
			$headers->{$key} = $defaults->{$key} unless (defined $headers->{$key});
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# From                                                                             #
		#----------------------------------------------------------------------------------#
		my $smtp = $account->{smtp};
		if ($smtp->mail($account->{address}))
		{
			$headers->{'From'} = $account->{name} . '<' . $account->{address} . '>';
		}
		else
		{
			WARN("Can't send from " . $account->{address} . " : $!");
			return undef;
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# To, CC and BCC                                                                   #
		#----------------------------------------------------------------------------------#
		my $to  = VerifyAddresses($params->{to});
		my $cc  = VerifyAddresses($params->{cc});
		my $bcc = VerifyAddresses($params->{bcc});

		if (!($smtp->recipient(MergeRecipients($to, $cc, $bcc))))
		{
			WARN ("Unable to set email recipients : $!");
			return undef;
		}

		$headers->{'To'} = FormattAddresses($to);
		$headers->{'Cc'} = FormattAddresses($cc) if (scalar keys %$cc > 0);
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Subject                                                                          #
		#----------------------------------------------------------------------------------#
		$headers->{'Subject'} = (defined $params->{subject}) ? $params->{subject} : "[no subject]";
		$headers->{'Subject'} = encode('MIME-Header', $headers->{'Subject'});
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Message                                                                          #
		#----------------------------------------------------------------------------------#
		{
			my @content = ();

			#----------------------------------------------------------------------------------#
			# Email with attachments                                                           #
			#----------------------------------------------------------------------------------#
			if ((defined $params->{attach}) && (ref $params->{attach} eq 'ARRAY') && (scalar @{$params->{attach}} > 0))
			{
				$headers->{'Content-type'} = "multipart/mixed\; boundary=\"$boundary\"";
				push (@content, "This is a MIME encoded message.\n");

				#----------------------------------------------------------------------------------#
				# Embedd the multipart here                                                        #
				#----------------------------------------------------------------------------------#
				if ((defined $params->{text}) || (defined $params->{html}))
				{
					my $innerboundary = Boundary();

					push (@content, "\n\n--$boundary");
					push (@content, "Content-Type: multipart/alternative; boundary=\"$innerboundary\"");

					#----------------------------------------------------------------------------------#
					# Add optional text part                                                           #
					#----------------------------------------------------------------------------------#
					if (defined $params->{text})
					{
						push (@content, "\n\n--$innerboundary");
						push (@content, "Content-type: text/plain");
						# push (@content, "Content-type: text/plain; charset=\"$charset\"");
						# push (@content, "Content-Transfer-Encoding: quoted-printable\n");
						push (@content, $params->{text});
					}
					#----------------------------------------------------------------------------------#


					#----------------------------------------------------------------------------------#
					# Add optional html part                                                           #
					#----------------------------------------------------------------------------------#
					if (defined $params->{html})
					{
						push (@content, "\n\n--$innerboundary");
						push (@content, "Content-Type: text/html; charset=\"$charset\"");
						# push (@content, "Content-Transfer-Encoding: quoted-printable\n");
						push (@content, $params->{html});
					}
					#----------------------------------------------------------------------------------#

					push (@content, "\n\n--$innerboundary--");
				}
				#----------------------------------------------------------------------------------#


				#----------------------------------------------------------------------------------#
				# Add attachments                                                                  #
				#----------------------------------------------------------------------------------#
				foreach my $attachment (@{$params->{attach}})
				{
					$attachment = Attach($attachment);
					if ($attachment)
					{
						push (@content, "\n\n--$boundary");
						push (@content, $attachment);
					}
				}
				#----------------------------------------------------------------------------------#

				push (@content, "\n\n--$boundary--");
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Html with optional text email                                                    #
			#----------------------------------------------------------------------------------#
			elsif (defined $params->{html})
			{
				if (defined $params->{text})
				{
					$headers->{'Content-type'} = "multipart/alternative\; boundary=\"$boundary\"";

					push (@content, "This is a MIME encoded message.");
					push (@content, "\n\n--$boundary");
					push (@content, "Content-type: text/plain; charset=\"$charset\"");
					push (@content, "Content-Transfer-Encoding: quoted-printable\n");
					push (@content, $params->{text});
					push (@content, "\n\n--$boundary");
					push (@content, "Content-Type: text/html; charset=\"$charset\"\n");
					push (@content, $params->{html});
					push (@content, "\n\n--$boundary--");
				}
				else
				{
					$headers->{'Content-type'} = "text/html; charset=\"$charset\"";
					push (@content, $params->{html});
				}
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Text Only Email                                                                  #
			#----------------------------------------------------------------------------------#
			else
			{
				$headers->{'Content-type'} = "text/plain; charset=\"$charset\"";
				$headers->{'Content-Transfer-Encoding'} = "quoted-printable";

				push (@content, (defined $params->{text}) ? $params->{text} : "");
			}
			#----------------------------------------------------------------------------------#

			$content = join("\n", @content);
			$headers = join("\n", map { "$_: " . $headers->{$_} } keys %$headers);
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Send email                                                                       #
		#----------------------------------------------------------------------------------#
		if ($smtp->data())
		{
			$smtp->datasend($headers);
			$smtp->datasend("\n\n");
			$smtp->datasend($content);
			$smtp->dataend();
		}
		else
		{
			WARN("SMTP refused data : $!");
			return undef;
		}
		#----------------------------------------------------------------------------------#

		return 1;
	}

	return undef;
}
#########################################||#########################################



################################|     SendText     |################################
# sub SendText
# {	
# }
#########################################||#########################################



############################|     VerifyAddresses     |#############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub VerifyAddresses
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
				elsif ($param =~ /\"(.+)\" <(.+)>/i)
				{
					$retval = { $2 => $1 };
				}
				else
				{
					$retval = { $param => $param };
				}
			}

			$retval;
		};
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Validate : Make sure each address is valid                                       #
		#----------------------------------------------------------------------------------#
		foreach my $key (keys %$addresses)
		{
			my $val = $addresses->{$key};

			if (valid($key))
			{
				$val =~ s/;//g;
				$result->{$key} = $val;
			}
			elsif (valid($val))
			{
				$key =~ s/;//g;
				$result->{$val} = $key;
			}
		}
		#----------------------------------------------------------------------------------#
	}

	return $result;
}
#########################################||#########################################



1;