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
	use Scalar::Util qw(reftype);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Error Document Template                                                          #
#----------------------------------------------------------------------------------#
our $TEMPLATE = <<TEMPLATE;
<!doctype html>
<html lang=en>
	<head>
		<meta charset=utf-8>
		<title>[title]</title>

		<style type="text/css">
		</style>

		<script>
		</script>
	</head>
	<body>
		[message]
	</body>
</html>
TEMPLATE
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT = qw(barf Route Respond);
	our $STATE  = 0; # Initial State
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



###############################|     Make Error     |###############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub mkerror
{
	my ($message, $title) = @_;
	$title = 'Error' unless ($title);

	my $template = $TEMPLATE;

	$template =~ s/\[title\]/$title/gi;
	$template =~ s/\[message\]/$message/gi;

	return $template;
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
		$code->($request, GetContent());
		$STATE = 2; # Resource Execution Complete
	}
	#----------------------------------------------------------------------------------#

	exit; # If we got this far, we did it, and we don't want to eval any further
}
#########################################||#########################################



#################################|     Respond     |################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub Respond($)
{
	my ($params) = @_;

	if (reftype $params eq 'HASH')
	{
		my $content = $params->{content};
		delete($params->{content});

		$params->{'-type'}    = NegotiateType($params->{'-type'});
		$params->{'-status'}  = "200 Success" unless ($params->{'-status'});
		$params->{'-charset'} = "ISO-8859-1" unless ($params->{'-charset'});

		if ($Metaphor::Scripting::QUERY->can("no_cache"))
		{
			$Metaphor::Scripting::QUERY->no_cache(1);
		}

		print $Metaphor::Scripting::QUERY->header($params);
		SetContent($content, $params->{'-type'});
	}
	else
	{
		barf('500', 'Malformed Response');
	}
}
#########################################||#########################################


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
				print $Metaphor::Scripting::QUERY->header( -status => $ERROR->{status}, -type => 'text/html' );
				print mkerror($ERROR->{message});
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Handle anything else
			#----------------------------------------------------------------------------------#
			else
			{
				print $Metaphor::Scripting::QUERY->header( -status => 500, -type => 'text/html' );
				print mkerror("<p>$ERROR</p>", 'Server Error');
			}
			#----------------------------------------------------------------------------------#
		}
		else
		{
			print $Metaphor::Scripting::QUERY->header(-status => 501, -type => 'text/html');
			print mkerror('<h1>Not Implemented</h1><i>' . $Metaphor::Scripting::QUERY->request_method() . ' : ' . $Metaphor::Scripting::QUERY->self_url() . '</i>', 'Server Error');
		}
		#----------------------------------------------------------------------------------#
	}
}
#----------------------------------------------------------------------------------#



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