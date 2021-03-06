package Metaphor::Config;

#########################################||#########################################
#                                                                                  #
# Metaphor::Config                                                                 #
# � Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Cwd qw(abs_path);
	use English qw(-no_match_vars);
	use JSON::MaybeXS;
	use Try::Tiny;
	use Metaphor::Util qw(Declassify);
	use XML::Simple qw(:strict);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $VERSION = '1.0.0';
	our @EXPORT  = qw(GetConfig LoadConfig);
	our $CONFIG  = undef;
	our $DEFAULT = "config.json";

	our $FILE_PATH_SEPARATOR = q{/};
#----------------------------------------------------------------------------------#


###############################|     GetConfig     |################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub GetConfig
{
	if ((!defined $CONFIG) || (ref $CONFIG ne 'HASH'))
	{
		$CONFIG = LoadConfig(@_);
	}

	return $CONFIG;
}
#########################################||#########################################



###############################|     LoadConfig     |###############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub LoadConfig
{
	my ($file) = Declassify(\@_, __PACKAGE__);
	$file = Locate($file);

	if ($file)
	{
		if ($file =~ /\.xml$/mi)
		{
			return LoadXML($file);
		}
		elsif ($file =~ /\.json$/mi)
		{
			my $json = LoadJson($file);
			return $json;
		}
	}

	return {};
}
#########################################||#########################################



################################|     LoadJson     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub LoadJson
{
	my $file = shift;

	my $data = do
	{
		my $json   = {};
		my $opened = open(my $json_fh, "<:encoding(UTF-8)", $file);
		if ($opened)
		{
			local $INPUT_RECORD_SEPARATOR = undef;
			$json = <$json_fh>;
			my $closed = close($json_fh);

			if (!$closed)
			{
				DEBUG("Error closing $file : $ERRNO")
			}
		}

		$json;
	};

	try
	{
		$data = decode_json($data);
	}
	catch
	{
		DEBUG("Error decoding JSON ($file) : $ERRNO");
		$data = {};
	};

	return $data;
}
#########################################||#########################################



#################################|     LoadXML     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub LoadXML
{
	my $file = shift;
	return XMLin($file, ForceArray => 0, KeyAttr => {});
}
#########################################||#########################################



#################################|     Locate     |#################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Locate
{
	my $file = ((scalar @_ > 0) && ($_[0])) ? shift : $DEFAULT;

	if ($file)
	{
		if (-e "./$file")
		{
			return abs_path("./$file");
		}
		else
		{
			foreach my $location (@INC)
			{
				my $location = join($FILE_PATH_SEPARATOR, ($location, $file));
				return $location if (-e $location);
			}
		}
	}

	return;
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Metaphor::Config - Locates and loads a JSON or XML configuration file.

=head1 SYNOPSIS

 use Metaphor::Config; # Exports GetConfig and LoadConfig

 my $config1 = GetConfig();
 my $config2 = LoadConfig("config.xml");

=head1 DESCRIPTION

Sensible defaults allows you to easily include and access a configuration file anywhere in your project.

=head2 Methods

Only public methods are documented.

=over 12

=item C<GetConfig([FILENAME])>

FILENAME is optional.  If omitted, it defaults to 'config.json'.  If specified, it can be an absolute path to a file or a path to a file relative to any path in @INC.

If the FILENAME does not exist, then each path in @INC is searched for the FILENAME, and the first one found will be used.

On first call, loads the file into a hashref using either JSON::PP or XML::SIMPLE (based on the extension).  On subsequent calls - even if a parameter is passed - the cached hashref is returned.

=item C<LoadConfig([FILENAME])>

FILENAME is optional.  If omitted, it defaults to 'config.json'.  If specified, it can be an absolute path to a file or a path to a file relative to any path in @INC.

If the FILENAME does not exist, then each path in @INC is searched for the FILENAME, and the first one found will be used.

Returns the file as a hashref using either JSON::PP or XML::SIMPLE (based on the extension). The hashref is not cached, and so will be read from disk each time.

=back

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

=over 1

=item * L<JSON::PP|http://search.cpan.org/~makamaka/JSON-PP-2.27203/lib/JSON/PP.pm>

=item * L<XML::Simple|http://search.cpan.org/~grantm/XML-Simple-2.20/lib/XML/Simple.pm>

=back

=cut