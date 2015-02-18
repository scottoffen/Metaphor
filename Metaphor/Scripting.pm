package Metaphor::Scripting;
our $VERSION = '1.0.0';

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
BEGIN
{
	#----------------------------------------------------------------------------------#
	# Try to use CGI::Simple, fallback on CGI.pm, croak if everything fails            #
	#----------------------------------------------------------------------------------#
	$ENV{'CGI'} = do
	{
		eval { require CGI::Simple };

		if ($@)
		{
			eval { require CGI; import CGI(":standard") };
			croak "Unable to load CGI or CGI::Simple : $@" if ($@);
			new CGI();
		}
		else
		{
			new CGI::Simple();
		}
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
				'modules' => [ 'JSON::Any', 'JSON::XS' , 'JSON::PP' ]
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

			eval
			{
				load $val->{default};
				$val->{default}->import();
			};

			if ($@)
			{
				foreach my $impl (@{$val->{modules}})
				{
					eval
					{
						load $impl;
						$impl->import();
					};

					unless ($@)
					{
						$Parsers{$format} = $impl;
						last;
					}
				}

				if ($@)
				{
					$Parsers{$format} = 0;
					warn("$format Support Not Detected!!");
				}
			}
			else
			{
				$Parsers{$format} = $val->{default};
			}
		}

		$ENV{'PARSERS'} = \%Parsers;
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
	our $MODE   = ($ENV{'CGI'}->param('mode')) ? $ENV{'CGI'}->param('mode') : 0;
	our @EXPORT = qw(GetContent NegotiateType SetContent $MODE);

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
		if ((!$ENV{'CONTENT_TYPE'}) || ($ENV{'CONTENT_TYPE'} =~ /^(application\/x-www-form-urlencoded|multipart\/form-data).*$/i))
		{
			my @keys = $ENV{CGI}->param;
			foreach my $key (@keys)
			{
				$CONTENT->{$key} = $ENV{CGI}->param($key);
			}
		}
		#------------------------------------------------------------------------------------#


		#------------------------------------------------------------------------------------#
		# Other supported types                                                              #
		#------------------------------------------------------------------------------------#
		else
		{
			my $data = $ENV{CGI}->param('POSTDATA');

			#------------------------------------------------------------------------------------#
			# JSON                                                                               #
			#------------------------------------------------------------------------------------#
			if ($ENV{'CONTENT_TYPE'} =~ /(json|javascript)$/i)
			{
				try
				{
					if ($ENV{'PARSERS'}->{JSON})
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
			elsif ($ENV{'CONTENT_TYPE'} =~ /xml$/i)
			{
				try
				{
					if ($ENV{'PARSERS'}->{XML})
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
			elsif ($ENV{'CONTENT_TYPE'} =~ /yaml$/i)
			{
				try
				{
					if ($ENV{'PARSERS'}->{YAML})
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
			if (($type =~ /json$/i) && ($ENV{PARSERS}->{JSON}))
			{
				print encode_json($data);
			}
			elsif (($type =~ /xml$/i) && ($ENV{PARSERS}->{XML}))
			{
				print XMLout($data);
			}
			elsif (($type =~ /yaml$/i) && ($ENV{PARSERS}->{YAML}))
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

	return $type;
}
#########################################||#########################################



1;