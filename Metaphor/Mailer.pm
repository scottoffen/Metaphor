package Metaphor::Mailer;

#########################################||#########################################
#                                                                                  #
# Metaphor::Mailer                                                                 #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Module Initialization                                                            #
#----------------------------------------------------------------------------------#
# BEGIN
# {
# }
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
	use Metaphor::Config;
	use Metaphor::Logging;
	use Metaphor::Storage qw(GetFileAsBase64 GetFileName);
	use Metaphor::Util qw(RandomString TrimString Declassify);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $VERSION  = '1.0.0';
	our @EXPORT   = qw(SendText SendEmail);
	our $MAILER   = GetConfig()->{'mailer'} || { "accounts" => {}, "lists" => {} };
	our $LISTS    = $MAILER->{"lists"}      || {};
	our $SMTP     = {};
	our $ACCOUNTS = {};
	our $DEFAULT  = undef;

	#----------------------------------------------------------------------------------#
	# Create default host                                                              #
	#----------------------------------------------------------------------------------#
	our $HOST = undef;
	{
		if (defined $ENV{'HTTP_HOST'})
		{
			my @httphost = split(/\./, $1) if ($ENV{'HTTP_HOST'} =~ /^(.+)$/i);
			$HOST = join(".", ("mail", $httphost[-2], $httphost[-1]));
		}
	}
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
			Metaphor::Mailer->AddAccount($account);
		}

		$DEFAULT = $default if (($default) && (exists $ACCOUNTS->{$default}));
	}
	#----------------------------------------------------------------------------------#

#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Module Cleanup                                                                   #
#----------------------------------------------------------------------------------#
END
{
	foreach my $key (keys %{$SMTP})
	{
		my $smtp = $SMTP->{$key}->{smtp};
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



###############################|     AttachFile     |###############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub AttachFile
{
	my ($attach) = @_;

	if ((defined $attach) && (ref $attach eq 'HASH') && (defined $attach->{file}))
	{
		if ((-e $attach->{file}) && (!(-d $attach->{file})))
		{
			my $disposition = (defined $attach->{disposition}) ? $attach->{disposition} : 'attachment';
			my $filename    = (defined $attach->{filename}) ? $attach->{filename} : GetFileName($attach->{file});
			my $modified    = FormatDate((stat($attach->{file}))[9]);

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



###############################|     AttachHtml     |###############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub AttachHtml
{
	my ($html, $charset) = @_;

	my @attachment =
	(
		"Content-Transfer-Encoding: quoted-printable",
		"Content-type: text/html; charset=\"$charset\"\n",
		$html
	);

	return join("\n", @attachment);
}
#########################################||#########################################



###############################|     AttachText     |###############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub AttachText
{
	my ($text, $charset) = @_;

	my @attachment =
	(
		"Content-Transfer-Encoding: quoted-printable",
		"Content-type: text/plain; charset=\"$charset\"\n",
		$text
	);

	return join("\n", @attachment);
}
#########################################||#########################################



################################|     Boundary     |################################
# Private                                                                          #
# 0 : Optional, length of boundary string                                          #
#----------------------------------------------------------------------------------#
sub Boundary
{
	my $length     = ((@_) && ($_[0] =~ /^\d{1,2}$/)) ? shift : 20;
	my $result     = "=_NextPart_";
	my $characters = ".=_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ()+:?";

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
			$SMTP->{$label} = $account;
			return $SMTP->{$label};
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



###############################|     FormatDate     |###############################
# Private                                                                          #
# 0 : Optional, unix timestamp                                                     #
#----------------------------------------------------------------------------------#
sub FormatDate
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
	return join("; ", map { "\"" . $list->{$_} . "\" <$_>" } keys %$list);
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
		my $val = $_[0] || $DEFAULT;
		if (defined $val)
		{
			if ((ref $val eq 'HASH'))
			{
				$label = Metaphor::Mailer->AddAccount($val)
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
		if (exists $SMTP->{$label})
		{
			return $SMTP->{$label};
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

	return (keys %$merged);
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
#       text  => the plain text part of the email                                  #
# 	    html  => the html part of the email                                        #
# 	    files => an array of files (base64 encoded) or file paths to attach        #
#       headers => optional hashref of desired headers                             #
#     }                                                                            #
#----------------------------------------------------------------------------------#
sub SendEmail
{
	my ($params) = Declassify(\@_, __PACKAGE__);
	my $account  = GetConnection($params->{from});

	if ($account)
	{
		my ($headers, $content, $message);

		my $defaults = { 'X-Auto-Response-Suppress' => 'DR, RN, NRN, OOF, AutoReply', 'Mime-Version' => '1.0', 'Date' => FormatDate() };
		my $charset  = (defined $params->{charset}) ? $params->{charset} : "iso-8859-1";
		my $smtp     = $account->{smtp};

		#----------------------------------------------------------------------------------#
		# Headers                                                                          #
		#----------------------------------------------------------------------------------#
		{
			#----------------------------------------------------------------------------------#
			# Defaults                                                                         #
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

			$headers = join("\n", map { "$_: " . $headers->{$_} } keys %$headers);
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Content                                                                          #
		#----------------------------------------------------------------------------------#
		{
			#----------------------------------------------------------------------------------#
			# Create message parts                                                             #
			#----------------------------------------------------------------------------------#
			my $text  = (defined $params->{text}) ? AttachText($params->{text}, $charset) : AttachText("", $charset);
			my $html  = (defined $params->{html}) ? AttachHtml($params->{html}, $charset) : undef;
			my $files = undef;
			{
				if ((defined $params->{attach}) && (ref $params->{attach} eq 'ARRAY') && (scalar @{$params->{attach}} > 0))
				{
					$files = [];

					foreach my $attachment (@{$params->{attach}})
					{
						$attachment = AttachFile($attachment);
						push (@$files, $attachment) if ($attachment);
					}
				}
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Multipart-Alternative Conversion                                                 #
			#----------------------------------------------------------------------------------#
			if (($text) && ($html))
			{
				my $boundary = Boundary();
				$content = join("\n", ("Content-type: multipart/alternative\; boundary=\"$boundary\"\n\n--$boundary", $text, "\n--$boundary", $html, "\n--$boundary--"));
			}
			else
			{
				$content = $text;
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Multipart-Mixed Conversion                                                       #
			#----------------------------------------------------------------------------------#
			if (($files) && (scalar @$files > 0))
			{
				my $boundary = Boundary(21);
				$content = "Content-Type: multipart/mixed; boundary=\"$boundary\"\n\n--$boundary\n$content\n";

				foreach my $file (@$files)
				{
					$content .= "\n--$boundary\n$file\n";
				}

				$content .= "\n--$boundary--\n";
			}
			#----------------------------------------------------------------------------------#
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Send email                                                                       #
		#----------------------------------------------------------------------------------#
		{
			$message = join("\n", $headers, $content);

			if ($smtp->data())
			{
				$smtp->datasend($message);
				$smtp->dataend();
			}
			else
			{
				WARN("SMTP refused data : $!");
				return undef;
			}
		}
		#----------------------------------------------------------------------------------#

		# print "\n$message\n";

		return 1;
	}

	return undef;
}
#########################################||#########################################



################################|     SendText     |################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub SendText
{
	my ($params) = Declassify(\@_, __PACKAGE__);

	if (($params) && (ref $params eq 'HASH'))
	{
		my $text =
		{
			subject => '',
			from    => (defined $params->{from}) ? $params->{from} : $DEFAULT,
			to      => (defined $params->{to})   ? $params->{to}   : undef,
			text    => (defined $params->{text}) ? $params->{text} : undef
		};

		if ((defined $text->{to}) && (defined $text->{text}))
		{
			return SendEmail($text);
		}
	}

	return undef;
}
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

__END__

=pod

=head1 NAME

Metaphor::Mailer - Simple module for sending email and SMS-via-email (wraps Net::SMTP)

=head1 SYNOPSIS

In L<config.json|https://github.com/scottoffen/common-perl/wiki/Metaphor::Config>:

 {
     ...
     "mailer" :
     {
         "accounts" :
         {
             "default" : "user1",
             "user1"   :
             {
                 "mailhost" : "mail.domain.com",
                 "name"     : "Fake Person",
                 "address"  : "alias@domain.com",
                 "username" : "user@domain.com",
                 "password" : "cGFzc3dvcmQ="
             }
         },

        "lists" :
        {
            "allusers" :
            {
                "user1@domain.com" : "Fake User1",
                "user2@domain.com" : "Fake User2"
            }
        }
    }
}

This entry is encouraged, but optional, as you can always configure mailer accounts on-the-fly (but not lists). Note that passwords in the config file are expected to be L<base64-encoded|http://perldoc.perl.org/MIME/Base64.html>.

In your script:

 use Metaphor::Mailer;

 # Send an email using values from the above config.json
 my $result = SendEmail(
 {
     # Matches an existing labeled account
     "from" => "user1",

     # Matches an existing mailing list
     "to"   => "allusers",

     # Recipients can also be provided as a hashref
     # with the email address as the key...
     "cc"   => { "someuser@domain.com" => "Some Other User" },

     # ...or with the recipeint name as the key.  Either way,
     # a given email address can only occur once per recipient field.
     "bcc"  => { "Switch It Up" => "switch@domain.com" },

     # Optional, defaults to [no subject]
     "subject" => "Email Subject",

     # The text part of the email (optional)
     "text"  => "the plain text part of the email",

     # The html part of the email (optional)
     "html"  => "<b>The html part of the email</b>",

     # Files to attach to the email (optional)
     "attach" =>
     [
         { "filename"      => "path/to/file1.pdf" },
         {
             "filename"    => "path/to/file2.pdf",
             "disposition" => "inline",
             "id"          => "contentid"
         }
     ],

     # Optional email headers to include
     headers =>
     {
         "header" => "header value"
     }
 });


 # Add an account to send an email from
 my $label = Metaphor::Mailer->AddAccount(
 {
     # If no label is provided, the username is used as the label
     "label"    => "different",

     # The mailhost to send the email through, include port as needed
     "mailhost" => "mail.domain.com",

     # The senders name to be displayed
     "name"     => "Different Person",

     # The senders 'from' email account
     "address"  => "different.alias@domain.com",

     # The username of the account to send the email from
     # (May be different from the address, depending on your mail system)
     "username" => "different.user@domain.com",

     # The password for the account to send the email from
     "password" => "password"
 });


 # Send an email from the new account
 SendEmail(
 {
     "from"    => "different",
     "to"      => { "jdoe@domain.com" => "John Doe" },
     "subject" => "Short Email",
     "text"    => "This is a short email."
 });

 # Send an email from an on-the-fly account
 SendEmail(
 {
     "from"    =>
     {
         "mailhost" => "mail.domain.com",
         "name"     => "Adhoc Person",
         "address"  => "adhoc@domain.com",
         "username" => "adhoc@domain.com",
         "password" => "password"
     },
     "to"      => { "jdoe@domain.com" => "John Doe" },
     "subject" => "Longer Email",
     "text"    => "This is a longer email, but still kinda short."
 });


 # Send an email from the default account
 SendEmail(
 {
     "to"      => { "jdoe@domain.com" => "John Doe" },
     "subject" => "Longest Email",
     "text"  => "This is a very long email, because I'm not a huge talker."
 });


 # Send an SMS-via-email.  From and to follow the same conventions as with SendEmail.
 SendText(
 {
     "from" => "user1",
     "to"   => { "5555550123@tmomail.net" => "Fake T-Mobile User" },
     "text" => "Limit your text to 160 latin or 70 non-latin characters, please."
 });

=head1 DESCRIPTION

One-liners to easily send plain-text, alternative (html) and multi-part (attachments) formatted emails.

=head2 Methods

Only public methods are documented.  Use undocumented methods at your own risk.

=head3 Exported Methods

=over 4

=item C<SendEmail(HASHREF)>

Send an email to a preconfigured account - either from the config file or one you added - or an ah-hoc account.  Supports multiple recipients (including cc and bcc) and alternative (html) and multi-part (attachments) formats. Returns true (1) on success, undef on failure.

 my $result = SendEmail(
 {
     # Matches an existing labeled account
     "from" => "user1",

     # Matches an existing mailing list
     "to"   => "allusers",

     # Recipients can also be provided as a hashref
     # with the email address as the key...
     "cc"   => { "someuser@domain.com" => "Some Other User" },

     # ...or with the recipeint name as the key.  Either way,
     # a given email address can only occur once per recipient field.
     "bcc"  => { "Switch It Up" => "switch@domain.com" },

     # Optional, defaults to [no subject]
     "subject" => "Email Subject",

     # The text part of the email (optional)
     "text"  => "the plain text part of the email",

     # The html part of the email (optional)
     "html"  => "<b>The html part of the email</b>",

     # Files to attach to the email (optional)
     "attach" =>
     [
         { "filename"      => "path/to/file1.pdf" },
         {
             "filename"    => "path/to/file2.pdf",
             "disposition" => "inline",
             "id"          => "contentid"
         }
     ],

     # Optional email headers to include
     headers =>
     {
         "header" => "header value"
     }
 });

Files to be attached are expected to be stored on disk before sending, but can be deleted immediately afterwards.

=item C<SendText(HASHREF)>

An alias for SendEmail that only supports the fields specific to sending an SMS via email. Returns true (1) on success, undef on failure.

 # Send an SMS-via-email; from/to follow the same conventions as SendEmail.
 SendText(
 {
     "from" => "user1",
     "to"   => { "5555550123@tmomail.net" => "Fake T-Mobile User" },
     "text" => "Plz limit txt 2 160 latin or 70 non-latin characters"
 });

=back

=head3 Other Methods

=over 4

=item C<AddAccount(HASHREF)>

Add accounts to send from or update an account already added (via the config file, ad-hoc or previous use of C<AddAccount>).  Returns the label for the account on success, undef on failure.

 my $label = Metaphor::Mailer->AddAccount(
 {
     "label"    => "different",
     "mailhost" => "mail.domain.com",
     "name"     => "Different Person",
     "address"  => "different.alias@domain.com",
     "username" => "different.user@domain.com",
     "password" => "password"
 });

If the C<label> field is omitted, the username is used as the label.  The password should not be encoded, however the password will be encoded when stored in memory, and is expected to be encoded if saved in the config file.

When calling C<SendEmail> with an ad-hoc account, the account is added behind the scenes using C<AddAccount>. Hence, if a label is provided on the call to C<SendEmail>, then the label can be reused in subsequent calls.  However, if you are going to do this, you might as well just use C<AddAccount> in the first place.

=back

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

=over 1

=item * L<Metaphor::Config|https://github.com/scottoffen/common-perl/wiki/Metaphor::Config>

=item * L<Metaphor::Logging|https://github.com/scottoffen/common-perl/wiki/Metaphor::Logging>

=item * L<Metaphor::Storage|https://github.com/scottoffen/common-perl/wiki/Metaphor::Storage>

=item * L<Metaphor::Util|https://github.com/scottoffen/common-perl/wiki/Metaphor::Util>

=item * L<Encode|http://perldoc.perl.org/Encode.html>

=item * L<Mail::RFC822::Address|https://github.com/scottoffen/common-perl/blob/master/Mail/RFC822/Address.pm>

=item * L<MIME::Base64|http://perldoc.perl.org/MIME/Base64.html>

=item * L<Net::SMTP|http://perldoc.perl.org/Net/SMTP.html>

=item * L<Time::Local|http://perldoc.perl.org/Time/Local.html>

=back

=cut