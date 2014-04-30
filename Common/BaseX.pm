package Common::BaseX;
our $VERSION = '0.9';

#########################################||#########################################
#                                                                                  #
# Common::BaseX                                                                    #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Common::Logging;
#----------------------------------------------------------------------------------#


##################################|     new     |###################################
# Public                                                                           #
#----------------------------------------------------------------------------------#
sub new
{
	#----------------------------------------------------------------------------------#
	# Get the class information and create the object to be blessed                    #
	#----------------------------------------------------------------------------------#
	my $class = shift;
	my $self  = {};
	my $valid = 1;
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Initialize the object                                                            #
	#----------------------------------------------------------------------------------#
	$self->{base10} = {};
	$self->{baseX}  = {};
	$self->{base}   = 0;
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Get incoming parameters                                                          #
	#----------------------------------------------------------------------------------#
	if (@_)
	{
		my @digits = GetCharacterSet(@_);
		my $digits = scalar @digits;

		if ($digits > 1)
		{
			$self->{base} = $digits;

			for (my $i = 0; $i < $digits; $i += 1)
			{
				$self->{baseX}->{$digits[$i]} = $i;
				$self->{base10}->{$i} = $digits[$i];
			}
		}
		else
		{
			$valid = 0;
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Bless and return the object                                                      #
	#----------------------------------------------------------------------------------#
	if ($valid)
	{
		bless($self, $class);
		return $self;
	}
	else
	{
		DEBUG("Insufficient characters provided to create BaseX");
		return undef;
	}
	#----------------------------------------------------------------------------------#
}
#########################################||#########################################



############################|     ConvertToBase10     |#############################
# Public                                                                           #
#----------------------------------------------------------------------------------#
sub ConvertToBase10
{
	my $self   = shift;
	my $base_x = shift;
	my $base10 = 0;

	my @digits = GetDigits($base_x, $self->{baseX});
	my $power  = scalar @digits;

	for (my $i = 0; $i < scalar @digits; $i++)
	{
		$power--;
		$base10 += $self->{baseX}->{$digits[$i]} * ($self->{base}**$power);
	}

	return $base10;
}
#########################################||#########################################



###########################|     ConvertFromBase10     |############################
# Public                                                                           #
#----------------------------------------------------------------------------------#
sub ConvertFromBase10
{
	my $self   = shift;
	my $base10 = shift;
	my $base_x = undef;

	if ($base10 =~ /^\d+$/)
	{
		while ($base10 >= $self->{base})
		{
			my $digit = $base10 % $self->{base};
			$base_x = (defined $base_x) ? $self->{base10}->{$digit} . $base_x : $self->{base10}->{$digit};
			$base10 = int($base10 / $self->{base});
		}

		$base_x = $self->{base10}->{$base10} . $base_x;
	}

	return $base_x;
}
#########################################||#########################################



############################|     GetCharacterSet     |#############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetCharacterSet
{
	my $input = join('', @_);

	if (length $input > 0)
	{
		my (%unique, @unique);
		my @charset = split('', $input);

		foreach my $char (@charset)
		{
			my $ascii = ord($char);

			if (($ascii > 31) && ($ascii < 127))
			{
				if (!exists $unique{$char})
				{
					$unique{$char} = 1;
					push(@unique, $char);
				}
			}

		}

		return @unique;
	}

	return undef;
}
#########################################||#########################################



###############################|     GetDigits     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetDigits
{
	my ($input, $valid) = @_;

	$valid = join('', keys %$valid);
	$input =~ s/[^$valid]//g;

	return split('', $input);
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Common::BaseX - Allows for integer conversion of arbitrary numbering systems between base I<x> and base 10.

=head1 SYNOPSIS

    use Common::BaseX;

    my $base17  = new Common::BaseX('0123456789abcdefg');
    my $baseXYZ = new Common::BaseX('x', 'y', 'z');
    my $value   = 101;

    $value = $base17->ConvertFromBase10($value);
    print "$value\n";

    # output:
    # 5g

    $value = $base17->ConvertToBase10($value);
    print "$value\n";

    # output:
    # 101

    $value = $baseXYZ->ConvertFromBase10($value);
    print "$value\n";

    # output:
    # yxzxz

=head1 DESCRIPTION

Create your own numbering systems using any arbitrary set of characters in any order, and convert to and from base 10 numbers!  Convert between two number systems using base 10 as an intermediary!

B<Note:> This module does not convert plain text to a base x number.  If you want to convert plain text, you should first convert the text to a number.  I would suggest using L<perl's native ord function|http://perldoc.perl.org/functions/ord.html> to assist with that.

=head2 Methods

Only public methods are documented.

=over 12

=item C<new(STRING|ARRAY)>

The input array is parsed into an array of L<ascii-printable characters|http://en.wikipedia.org/wiki/ASCII#ASCII_printable_characters> ordered by their first occurrence in the array and used as a numbering system.

    # All three of these are using the same numbering system
    my $foo = new Common::BaseX('scott offen');
    my $bar = new Common::BaseX('scott', 'scott', 'offen', 'soften');
    my $baz = new Common::BaseX('s', 'c', 'o', 't', 'f', 'e', 'n');

While this means that you I<can> pass a value multiple times, it is not recommended, as this will likely end up with results you did not intend.

=item C<ConvertToBase10(STRING)>

Attempts to convert a string of characters to base 10 using the internal numbering system created when the object was initialized.  Any characters not in the number system will be stripped out prior to conversion.

    my $abc = new Common::BaseX('abc');
    my $val = $abc->ConvertToBase10('abc');

    my $foo = $abc->ConvertToBase10('a9bc'); # Contains a value not in the numbering system
    my $bar = $abc->ConvertToBase10('1abc'); # Contains a value not in the numbering system
    my $baz = $abc->ConvertToBase10('abcZ'); # Contains a value not in the numbering system

    print "$val = $foo = $bar = $baz";

    # output
    # 5 = 5 = 5 = 5

=item C<ConvertFromBase10(INTEGER)>

Attempts to convert a base 10 number to a string of characters using the internal numbering system created when the object was initialized.  Returns a string result.

=back

=head1 TODO

At some point I'd like to implement methods that would convert plain text to/from base x number systems, but I've yet to have a need for it.

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

L<Common::Logging|https://github.com/scottoffen/Common-Perl/wiki/Common::Logging>

=cut