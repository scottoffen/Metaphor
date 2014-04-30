package Common::Util;
our $VERSION = '0.9';

#########################################||#########################################
#                                                                                  #
# Common::Util                                                                     #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Time::HiRes;
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT = qw(
		CreateGuid
		RandomString
		RandomNumber
		TrimString
		IsGuid
		IsEmail
		IsBool
		IsNumber
		IsNumberInRange
		IsPhone
		FormatPhone
		IsIPAddress
		IsPostalCode
		IsCreditCard
		CompareString
	);

	our @EXPORT_OK = @EXPORT;

	our %EXPORT_TAGS =
	(
		'generators' => [qw(CreateGuid RandomString RandomNumber)],
		'formatters' => [qw(TrimString FormatPhone)],
		'validators' => [qw(IsGuid IsEmail IsBool IsNumber IsNumberInRange IsPhone IsIPAddress IsPostalCode IsCreditCard)],
	);
#----------------------------------------------------------------------------------#


##############################|     Create Guid     |###############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub CreateGuid
{
	my $guid = '09EAB114C555' . sprintf("%05d", $$) . sprintf("%.6f", Time::HiRes::time());

	$guid =~ s/\.//g;
	$guid = substr($guid, 0, 8) . '-' . substr($guid, 8, 4) . '-' . substr($guid, 12, 4) . '-' . substr($guid, 16, 4) . '-' . substr($guid, 20, 12);

	return $guid;
}
#########################################||#########################################



##############################|     RandomString     |##############################
# Exported                                                                         #
# 0 : Length of string                                                             #
#----------------------------------------------------------------------------------#
sub RandomString
{
	my $length = shift || 10;
	my @chars  = ('A'..'Z','0'..'9');

	my $result;

	foreach (1..$length)
	{
		$result .= $chars[rand @chars];
	}

	return $result;
}
#########################################||#########################################



##############################|     RandomNumber     |##############################
# Exported                                                                         #
# 0 : Range                                                                        #
# 1 : Offset                                                                       #
#----------------------------------------------------------------------------------#
sub RandomNumber
{
    my $range   = ((@_) && ($_[0] =~ /^(\d+$)/)) ? shift : 1;
    my $offset  = ((@_) && ($_[0] =~ /^(\d+$)/)) ? shift : 0;
    my $result  = int(rand($range)) + $offset;

    return $result;
}
#########################################||#########################################



###############################|     TrimString     |###############################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub TrimString
{
	my $value = shift;

	$value =~ s/^\s+//;
	$value =~ s/\s+$//;

	return $value;
}
#########################################||#########################################



#################################|     IsGuid     |#################################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsGuid
{
	my $value  = shift;
	my $result = (($value) && ($value =~ /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/i)) ? 1 : 0;

    return $result;
}
#########################################||#########################################



################################|     IsEmail     |#################################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsEmail
{
	my $value  = shift;
	my $result = (($value) && ($value =~ /^[a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,4}$/)) ? 1 : 0;

	return $result;
}
#########################################||#########################################



#################################|     IsBool     |#################################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsBool
{
	my $value  = shift;

	if (defined $value)
	{
		if ($value =~ /^(0|1)$/)
		{
			return 1;
		}
	}

	return 0;
}
#########################################||#########################################



##############################|     IsIPAddress     |###############################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsIPAddress
{
	my $value  = shift;

	if (defined $value)
	{
		if ($value =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/i)
		{
			my @octets = split('\.', $value);

			foreach my $octet (@octets)
			{
				return 0 if ($octet > 255);
			}

			return 1;
		}
	}

	return 0;
}
#########################################||#########################################



################################|     Is Phone     |################################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsPhone
{
	my $value  = shift;

	if (defined $value)
	{
		$value =~ s/\D//g; #--> Removes all non-digit characters from the string
		if ($value =~ /\d{10,}/)
		{
			return $value;
		}
	}

	return 0;
}
#########################################||#########################################



##############################|     FormatPhone     |###############################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub FormatPhone
{
	my $value = ((scalar @_ > 0) && (defined $_[0])) ? shift : undef;

	if (defined $value)
	{
		$value =~ s/\D//g;
		if ($value =~ /^\d{10}$/)
		{
			$value = "(" . substr($value, 0, 3) . ") " . substr($value, 3, 3) . "-" . substr($value, 6);
		}
	}

	return $value;
}
#########################################||#########################################



################################|     IsNumber     |################################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsNumber
{
	my $value = ((scalar @_ > 0) && (defined $_[0])) ? shift : undef;

	if (defined $value)
	{
		if ($value =~ /^[\-\+]?\d+\.?\d*$/)
		{
			return 1;
		}
	}

	return 0;
}
#########################################||#########################################



############################|     IsNumberInRange     |#############################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsNumberInRange
{
	my $value  = shift;
	my $min    = shift;
	my $max    = shift;

	if (defined $value)
	{
		if ((IsNumber($value)) && (IsNumber($min)) && (IsNumber($max)))
		{
			if (($value >= $min) && ($max >= $value))
			{
				return 1;
			}
		}
	}

	return 0;
}
#########################################||#########################################



##############################|     IsPostalCode     |##############################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsPostalCode
{
	my $value = ((scalar @_ > 0) && (defined $_[0])) ? shift : undef;

	if (defined $value)
	{
		if (($value =~ /^\d{5}(\-?\d{4})?$/) || ($value =~ /^[A-Z]\d[A-Z]\d[A-Z]\d$/i))
		{
			return 1;
		}
	}

	return 0;
}
#########################################||#########################################



#############################|     Is Credit Card     |#############################
# Exported                                                                         #
# 0 : String                                                                       #
#----------------------------------------------------------------------------------#
sub IsCreditCard
{
	my $value = ((scalar @_ > 0) && (defined $_[0])) ? shift : undef;

	if (defined $value)
	{
		if (($value =~ /^\d{15,16}$/))
		{
			return 1;
		}
	}

	return 0;
}
#########################################||#########################################



#############################|     Compare String     |#############################
# Exported                                                                         #
# 0 : String                                                                       #
# 1 : String                                                                       #
#----------------------------------------------------------------------------------#
sub CompareString
{
	my ($x, $y) = map {lc} @_;
	return undef unless (($x) && ($y));
	return ($x gt $y) ? 1 : ($x lt $y) ? -1 : 0;
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Common::Util - All kinds of fun little utility methods that get used all the freaking time!

=head1 SYNOPSIS

    use Common::Util; # All of the methods below are exported by default

    use Common::Util(':generators'); # Only exports generators
    use Common::Util(':formatters'); # Only exports formatters
    use Common::Util(':validators'); # Only exports validators

    #----- G E N E R A T O R S -----#

    # Generates a pseudo-guid
    my $guid = CreateGuid();

    # Generates a random string of 10 alphanumeric characters
    my $random = RandomString(10);

    # Generates a random number between 2 and 11
    my $randnum = RandomNumber(10, 2);


    #----- F O R M A T T E R S -----#

    # Removes all white space before and after a string
    my $trimmed = TrimString("  	trimmed	  ");

    # Formats a phone number: (888) 999-1212
    my $phone1 = FormatPhone("888-999-1212");
    my $phone2 = FormatPhone("888.999.1212");
    my $phone3 = FormatPhone("888.999-1212");
    my $phone4 = FormatPhone(8889991212);


    #----- V A L I D A T O R S -----#

    IsGuid('foo');                                  # false
    IsGuid('09EAB114-C555-0465-6139-664515425218'); # true

    IsEmail('foo');                                 # false
    IsEmail('user@domain.com');                     # true

    IsBool(1);                                      # true
    IsBool(0);                                      # true
    IsBool('x');                                    # false

    IsNumber(1);                                    # true
    IsNumber("1");                                  # true
    IsNumber(1.003);                                # true
    IsNumber(+5.6);                                 # true
    IsNumber(-22);                                  # true
    IsNumber('1.z');                                # false

    IsNumberInRange(100,1,100);                     # true
    IsNumberInRange(50,1,100);                      # true
    IsNumberInRange(1,1,100);                       # true
    IsNumberInRange(100,1,50);                      # false
    IsNumberInRange(100,50,1);                      # false

    IsPhone(5552323);                               # false
    IsPhone(222555444);                             # false
    IsPhone(2225558887);                            # 2225558887 (true)
    IsPhone('(222) 555-8887');                      # 2225558887 (true)

    IsIPAddress('1.0.0.0');                         # true
    IsIPAddress('255.255.255.255');                 # true
    IsIPAddress('255.255.255.256');                 # false
    IsIPAddress('255.a.255.256');                   # false

    IsPostalCode('20500');                          # true
    IsPostalCode('20500-1234');                     # true
    IsPostalCode('K1A1B1');                         # true (Canadian)

    IsCreditCard(12345678901234);                   # false
    IsCreditCard(123456789012345);                  # true
    IsCreditCard(1234567890123456);                 # true
    IsCreditCard(12345678901234567);                # false

    CompareString('adam', 'beth');                  # -1
    CompareString('beth', 'adam');                  # 1
    CompareString('adam', 'adam');                  # 0

=head1 DESCRIPTION

An assortment of common helper methods for generating, formatting, and validating data.

=head2 Methods

Only public methods are documented.

=over 12


=item C<CompareString(STRINGA, STRINGB)>

Returns: (1) if STRINGB  is greater than STRINGA, (0) if STRINGA equals STRINGB or (-1) if STRINGA is greater than STRINGB.

=item C<CreateGuid()>

Returns a pseudo-guid as a 36 character string.

=item C<FormatPhone(PHONE_NUMBER)>

Attempts to formatt PHONE_NUMBER I<(888) 888-8888> and return the formatted string. At worst, returns the value passed in stripped of non-digit characters.

=item C<IsBool(VALUE)>

Returns (1) if the value passed in is a 1 or a 0, otherwise returns (0).

=item C<IsCreditCard(VALUE)>

Returns (1) if the value passed in is 15 or 16 digits long, otherwise returns (0).

=item C<IsEmail(VALUE)>

Returns (1) if the value passed in matches the internal email regular expression, otherwise returns (0).

=item C<IsGuid(VALUE)>

Returns (1) if the value passed in is a 36 character guid, otherwise returns (0).

See I<CreateGuid>.

=item C<IsIPAddress(VALUE)>

Returns (1) if the value passed in is an IPv4 address in the range of I<0.0.0.0> to I<255.255.255.255>, otherwise returns (0).

=item C<IsNumber(VALUE)>

Returns (1) if the value passed in is number-ish, otherwise returns (0).  Takes into consideration positive and negative signs and decimal values.

=item C<IsNumberInRange(VALUE, MIN, MAX)>

Returns (1) if the value passed in is between min and max (inclusive), otherwise returns (0).

=item C<IsPhone(VALUE)>

Returns the value passed in stripped of all non-digit characters if it contains at least 10 digits, otherwise returns (0).

=item C<IsPostalCode(VALUE)>

Returns (1) if the value passed in is formatted like an American (nnnnn or nnnnn-nnnn) or Canadian (xnx nxn or xnxnxn) postal code, otherwise returns (0).

=item C<RandomNumber(RANGE [, OFFSET])>

Returns a random number between 0 and RANGE, adds optional OFFSET to value before returning it.

=item C<RandomString([LENGTH])>

Returns a random alpha-numeric string of LENGTH length (which defaults to 10 if not provided).

=item C<TrimString(VALUE)>

Returns the value after removing extra leading and trailing whitespace.

=back

=head1 TODO

Implement the L<Luhn algorithm|http://en.wikipedia.org/wiki/Luhn_algorithm> in IsCreditCard method.

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

None

=cut