package Metaphor::Scripting;

#########################################||#########################################
#                                                                                  #
# Metaphor::Scripting                                                              #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Carp;
	use Data::Dumper;
	use Metaphor::Config;
	use Metaphor::Logging;
	use Metaphor::Util qw(TrimString);
	use Module::Load; # autoload not supported
	use Try::Tiny;
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Service Initialization                                                           #
#----------------------------------------------------------------------------------#
our ($QUERY, $PARSERS);
BEGIN
{
	#----------------------------------------------------------------------------------#
	# Try to use CGI::Simple, fallback on CGI.pm, croak if everything fails            #
	#----------------------------------------------------------------------------------#
	$Metaphor::Scripting::QUERY = do
	{
		my $cgi;

		try
		{
			require CGI::Simple;
			$cgi = CGI::Simple->new();
			$cgi->parse_query_string();
		}
		catch
		{
			try
			{
				require CGI;
				import CGI(":standard");
				$cgi = CGI->new();
			}
			catch
			{
				croak "Unable to load CGI or CGI::Simple : $_";
			};
		};

		$cgi;
	};
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Load Parsers                                                                     #
	#----------------------------------------------------------------------------------#
	{
		my %Parsers =
		(
			'JSON' =>
			{
				'default' => 'JSON::MaybeXS',
				'modules' => [ 'JSON::XS' , 'JSON::PP' ]
			},

			'YAML' =>
			{
				'default' => 'YAML::Any',
				'modules' => [ 'YAML', 'YAML::XS' , 'YAML::LibYAML', 'YAML::Syck', 'YAML::Old', 'YAML', 'YAML::Tiny' ]
			},

			# When selecting which XML parser to use, I would suggest consulting:
			# http://perl-xml.sourceforge.net/faq/#dont_parse
			'XML'  =>
			{
				'default' => 'XML::Simple',
				'modules' => [ ]
			}
		);

		foreach my $format (keys %Parsers)
		{
			my $val = $Parsers{$format};

			my $test = eval
			{
				load $val->{default};
				$val->{default}->import();
				1;
			};

			if ($test)
			{
				$Parsers{$format} = $val->{default};
			}
			else
			{
				foreach my $impl (@{$val->{modules}})
				{
					$test = eval
					{
						load $impl;
						$impl->import();
						1;
					};

					if ($test)
					{
						$Parsers{$format} = $impl;
						last;
					}
				}

				unless ($test)
				{
					$Parsers{$format} = 0;
					carp("$format Support Not Detected!!");
				}
			}
		}

		$PARSERS = \%Parsers;
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Set default environment variables and untaint them all                           #
	#----------------------------------------------------------------------------------#
	{
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
				next if (ref $ENV{$key});
				$ENV{$key} = $1 if ($ENV{$key} =~ /^(.*)$/)
			}
		}
	}
	#----------------------------------------------------------------------------------#
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $VERSION = '1.0.0';
	our $MODE    = ($QUERY->param('mode')) ? $QUERY->param('mode') : 0;
	our @EXPORT  = qw(GetContent NegotiateType SetContent $MODE);

	#----------------------------------------------------------------------------------#
	# Content-type definitions                                                         #
	#----------------------------------------------------------------------------------#
	our $TYPES =
	{
		'default' => 'application/json',
		'text'    => 'text/plain',
		'html'    => 'text/html',
		'json'    => 'application/json',
		'xml'     => 'text/xml',
		'appxml'  => 'application/xml',
		'yaml'    => 'text/yaml',
		'appyaml' => 'application/x-yaml'
	};
	#----------------------------------------------------------------------------------#

	Metaphor::Logging->Console($MODE);
	print "Content-type: text/html\n\n" if ($MODE);
#----------------------------------------------------------------------------------#


###############################|     GetContent     |###############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub GetContent
{
	my $CONTENT = {};
	my $content = {};

	#------------------------------------------------------------------------------------#
	# Parse data based on the content-type header                                        #
	#------------------------------------------------------------------------------------#
	{
		#------------------------------------------------------------------------------------#
		# Url encoded or multipart form data                                                 #
		#------------------------------------------------------------------------------------#
		my $types = join('|', ("application\\/x-www-form-urlencoded", "multipart\\/form-data"));
		if ((!$ENV{CONTENT_TYPE}) || ($ENV{CONTENT_TYPE} =~ /^($types).*$/i))
		{
			my @keys = $QUERY->param;
			foreach my $key (@keys)
			{
				$CONTENT->{$key} = $QUERY->param($key);
			}
		}
		#------------------------------------------------------------------------------------#


		#------------------------------------------------------------------------------------#
		# Other supported types                                                              #
		#------------------------------------------------------------------------------------#
		else
		{
			my $data = ($ENV{REQUEST_METHOD} =~ /PUT/i) ? $QUERY->param('PUTDATA') : $QUERY->param('POSTDATA');

			#------------------------------------------------------------------------------------#
			# JSON                                                                               #
			#------------------------------------------------------------------------------------#
			if ($ENV{CONTENT_TYPE} =~ /(json|javascript)$/i)
			{
				try
				{
					if ($PARSERS->{JSON})
					{
						$CONTENT = decode_json($data);
					}
					else
					{
						$CONTENT = { raw => $data };
					}
				}
				catch
				{
					WARN("Error Decoding JSON : $_");
				};
			}
			#------------------------------------------------------------------------------------#


			#------------------------------------------------------------------------------------#
			# XML                                                                                #
			#------------------------------------------------------------------------------------#
			elsif ($ENV{CONTENT_TYPE} =~ /xml$/i)
			{
				try
				{
					if ($PARSERS->{XML})
					{
						$CONTENT = XMLin($data);
					}
					else
					{
						$CONTENT = { raw => $data };
					}
				}
				catch
				{
					WARN("Error Decoding XML : $_");
				};
			}
			#------------------------------------------------------------------------------------#


			#------------------------------------------------------------------------------------#
			# YAML via YAML::Any                                                                 #
			#------------------------------------------------------------------------------------#
			elsif ($ENV{CONTENT_TYPE} =~ /yaml$/i)
			{
				try
				{
					if ($PARSERS->{YAML})
					{
						$CONTENT = Load($data);
					}
					else
					{
						$CONTENT = { raw => $data };
					}
				}
				catch
				{
					WARN("Error Decoding YAML : $_");
				};
			}
			#------------------------------------------------------------------------------------#
		}
		#------------------------------------------------------------------------------------#
	}
	#------------------------------------------------------------------------------------#


	#------------------------------------------------------------------------------------#
	# Normalize the key strings to lowercase                                             #
	#------------------------------------------------------------------------------------#
	foreach my $key (keys %$CONTENT)
	{
		$content->{lc($key)} = $CONTENT->{$key};
	}
	#------------------------------------------------------------------------------------#

	return $content; #--> Return the normalized content
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
	my $data = shift;
	my $type = shift;

	if ($data)
	{
		#------------------------------------------------------------------------------------#
		# Send the data                                                                      #
		#------------------------------------------------------------------------------------#
		{
			if (($type =~ /json$/i) && ($PARSERS->{JSON}))
			{
				try
				{
					print encode_json($data);
				}
				catch
				{
					my $error = "(json) " . $PARSERS->{JSON} . " : $_";
					DEBUG($error);
				}
			}
			elsif (($type =~ /xml$/i) && ($PARSERS->{XML}))
			{
				print XMLout($data);
			}
			elsif (($type =~ /yaml$/i) && ($PARSERS->{YAML}))
			{
				print Dump($data);
			}
			elsif ($type =~ /^text/i)
			{
				print $data;
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

	return;
}
#########################################||#########################################



#############################|     NegotiateType     |##############################
sub NegotiateType
{
	my ($type) = @_;

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
		elsif ($type =~ /^text/i)
		{
			$type = ($type =~ /html$/i) ? $TYPES->{'html'} : $TYPES->{'text'};
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
		my @accept = split(',', $ENV{HTTP_ACCEPT});
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

	return $type;
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