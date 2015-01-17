package Metaphor::REST;
our $VERSION = '1.0.0';

#########################################||#########################################
#                                                                                  #
# Metaphor::REST                                                                   #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Metaphor::Config;
	use Metaphor::Logging;
	use Metaphor::Scripting;
	use CGI qw(:standard);
	use CGI::Carp qw(fatalsToBrowser);
	use JSON::PP;
	use YAML::XS;
	use XML::Simple;
	use Data::Dumper;
	use Try::Tiny;
	use Scalar::Util qw(reftype);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Service Initialization                                                           #
#----------------------------------------------------------------------------------#
BEGIN
{
	#----------------------------------------------------------------------------------#
	# Set default environment variables and untaint them all                           #
	#----------------------------------------------------------------------------------#
	$ENV{REQUEST_METHOD} = 'GET' unless defined $ENV{REQUEST_METHOD};
	$ENV{HTTP_HOST}      = 'localhost' unless defined $ENV{HTTP_HOST};

	foreach my $key ('PATH_INFO', 'CONTENT_TYPE', 'HTTP_ACCEPT', 'REQUEST_URI')
	{
		$ENV{$key} = '' unless defined $ENV{$key};
	}

	foreach my $key (keys %ENV)
	{
		unless (ref $ENV{$key})
		{
			$ENV{$key} = $1 if ($ENV{$key} =~ /^(.*)$/)
		}
	}
	#----------------------------------------------------------------------------------#
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT = qw(barf Route SetContent);

	#----------------------------------------------------------------------------------#
	# Content-type definitions                                                         #
	#----------------------------------------------------------------------------------#
	our $TYPES =
	{
		'default' => 'application/json',
		'text'    => 'text/plain',
		'json'    => 'application/json',
		'xml'     => 'text/xml',
		'appxml'  => 'application/xml',
		'yaml'    => 'text/yaml',
		'appyaml' => 'application/x-yaml'
	};
	#----------------------------------------------------------------------------------#

	our $STATE = 0; # Initial State
	our $QUERY = new CGI();
	our $DEBUG = ((param('debug')) && (param('debug') == 1)) ? 1 : 0;
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Script Configuration                                                             #
#----------------------------------------------------------------------------------#
	Metaphor::Logging->Console($DEBUG);
	print "Content-type: text/html\n\n" if ($DEBUG);
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Service Cleanup                                                                  #
#----------------------------------------------------------------------------------#
END
{
	if ((1 > $STATE) || ($STATE > 2)) # Didn't match or errored on execution
	{
		print "Cache-Control: no-store, must-revalidate\n";


		#----------------------------------------------------------------------------------#
		# Handle Errors                                                                    #
		#----------------------------------------------------------------------------------#
		if ($@)
		{
			my $ERROR = $@;

			#----------------------------------------------------------------------------------#
			# Handle barfing                                                                   #
			#----------------------------------------------------------------------------------#
			if (ref $@ and reftype $@ eq 'HASH')
			{
				print $QUERY->header( -status => $ERROR->{status}, -type => 'text/html' );
				print $ERROR->{message};
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Handle anything else
			#----------------------------------------------------------------------------------#
			else
			{
				print $QUERY->header( -status => 500, -type => 'text/html' );
				print $QUERY->title('Server Error');
				print $QUERY->p( $ERROR );
			}
			#----------------------------------------------------------------------------------#
		}
		else
		{
			print $QUERY->header(-status => 501, -type => 'text/html');
			print $QUERY->h1('Not Implemented: ' . $QUERY->request_method);
		}
		#----------------------------------------------------------------------------------#
	}
}
#----------------------------------------------------------------------------------#


##################################|     barf     |##################################
# Exported                                                                         #
# 0 : Response Status Code                                                         #
# 1 : Message to return                                                            #
#----------------------------------------------------------------------------------#
sub barf
{
	my ($status, $message) = @_;
	$STATE = 3; # Trigger Error Condition

	die
	{
		status  => $status,
		message => $message
	};
}
#########################################||#########################################



##################################|     Route     |#################################
# Exported                                                                         #
# 0 : Request state to match (hash of arrays where the key is the ENV key)         #
# 1 : Code to execute if headers match                                             #
#----------------------------------------------------------------------------------#
sub Route($$)
{
	$STATE = 0;

	my ($headers, $code) = @_;
	my $request          = {};

	#----------------------------------------------------------------------------------#
	# Try to match headers                                                             #
	#----------------------------------------------------------------------------------#
	if ((ref $headers) && (reftype $headers eq 'HASH'))
	{
		HEADER : foreach my $key (keys %{$headers})
		{
			my @patterns = ((ref $headers->{$key}) && (reftype $headers->{$key} eq 'ARRAY')) ? @{$headers->{$key}} : ($headers->{$key});

			foreach my $pattern (@patterns)
			{
				if ($ENV{$key} =~ $pattern)
				{
					my @matches = ($ENV{$key} =~ $pattern);
					my $matches = scalar @matches;

					$request->{$key} = ($matches > 1) ? \@matches : ($matches > 0) ? $matches[0] : undef;

					next HEADER;
				}
			}

			return 0;
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# If the headers match, execute the code                                           #
	#----------------------------------------------------------------------------------#
	if ($code)
	{
		$STATE = 1; # Resource Match Found

		print "Cache-Control: no-store, must-revalidate\n";
		$code->($request, GetContent());

		$STATE = 2; # Resource Execution Complete
	}
	#----------------------------------------------------------------------------------#

	exit; # If we got this far, we did it, and we don't want to eval any further
}
#########################################||#########################################



###############################|     SetContent     |###############################
# Exported                                                                         #
# 0 : Data                                                                         #
# 1 : Content Type Key                                                             #
# 2 : Character Set                                                                #
#----------------------------------------------------------------------------------#
sub SetContent
{
	my $data    = shift;
	my $type    = shift;
	my $charset = shift;

	if ($data)
	{
		#------------------------------------------------------------------------------------#
		# Get the correct content type                                                       #
		#------------------------------------------------------------------------------------#
		{
			#------------------------------------------------------------------------------------#
			# Check for type in cannon                                                           #
			#------------------------------------------------------------------------------------#
			if (defined $type)
			{
				if ($type =~ /json$/i)
				{
					$type = $TYPES->{'json'};
				}
				elsif ($type =~ /xml$/i)
				{
					$type = ($type =~ /^app/i) ? $TYPES->{'appxml'} : $TYPES->{'xml'};
				}
				elsif ($type =~ /yaml$/i)
				{
					$type = ($type =~ /^app/i) ? $TYPES->{'appyaml'} : $TYPES->{'yaml'};
				}
				else
				{
					$type = undef;
				}
			}
			#------------------------------------------------------------------------------------#


			#------------------------------------------------------------------------------------#
			# Derive content type                                                                #
			#------------------------------------------------------------------------------------#
			if (!defined $type)
			{
				my @accept = split(',', $ENV{'HTTP_ACCEPT'});
				foreach my $accept (sort @accept)
				{
					foreach my $key (sort {uc($a) cmp uc($b)} keys %$TYPES)
					{
						my $val = $TYPES->{$key};
						if ($accept =~ /^$val$/i)
						{
							$type = $val;
						}
					}
				}
			}
			#------------------------------------------------------------------------------------#

			$type = $TYPES->{'default'} unless (defined $type);

			my $contenttype = (defined $charset) ? "Content-type: $type; charset=$charset" : "Content-type: $type";
			print "$contenttype\n\n";
		}
		#------------------------------------------------------------------------------------#


		#------------------------------------------------------------------------------------#
		# Send the data                                                                      #
		#------------------------------------------------------------------------------------#
		{
			if ($type =~ /json$/i)
			{
				print encode_json($data);
			}
			elsif ($type =~ /xml$/i)
			{
				print XMLout($data);
			}
			elsif ($type =~ /yaml$/i)
			{
				print Dump($data);
			}
			else
			{
				$data = Dumper($data);
				$data =~ s/^\$VAR1 = {\r?\n//i;
				$data =~ s/};$//;
				$data =~ s/=>/=/g;
				print $data;
			}
		}
		#------------------------------------------------------------------------------------#
	}
	else
	{
		print "Content-type: text/plain\n\n";
	}
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Metaphor::REST

=head1 SYNOPSIS



=head1 DESCRIPTION



=head2 Methods

Only public methods are documented.  Use undocumented methods at your own risk.

=head3 Exported Methods

=over 4

=item C<Method(PARAM)>



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