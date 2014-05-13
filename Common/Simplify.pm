package Common::Simplify;
our $VERSION = '0.9';

#########################################||#########################################
#                                                                                  #
# Common::Simplify                                                                 #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Scalar::Util qw(blessed);
#----------------------------------------------------------------------------------#


################################|     Simplify     |################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub Simplify
{
	my $self = shift;
	my $data = {};
	my @link = ((@_) && (scalar @_ > 0)) ? @_ : ();


	#----------------------------------------------------------------------------------#
	# Object data elements are pulled from the internal fields structure               #
	#----------------------------------------------------------------------------------#
	if (exists $self->{Fields})
	{
		if (ref $self->{Fields} eq 'HASH')
		{
			push (@link, $_) foreach (keys %{$self->{Fields}});
		}
		elsif (ref $self->{Fields} eq 'ARRAY')
		{
			push (@link, $_) foreach (@{$self->{Fields}});
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Add object properties to the data structure                                      #
	#----------------------------------------------------------------------------------#
	foreach my $key (@link)
	{
		#----------------------------------------------------------------------------------#
		# Special handeling for boolean values, as defined as any field that begins with   #
		# the letters 'Is' immediatly followed by a capital letter.                        #
		#----------------------------------------------------------------------------------#
		if ($key =~ /^Is[A-Z]\w+/)
		{
			$data->{$key} = ((defined $self->{$key}) && ($self->{$key} eq '1')) ? 'true' : 'false';
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Everything else                                                                  #
		#----------------------------------------------------------------------------------#
		else
		{
			$data->{$key} = '';

			#----------------------------------------------------------------------------------#
			# If the key is also a method, run the method before checking for a value.         #
			#----------------------------------------------------------------------------------#
			if ($self->can($key))
			{
				$self->$key;
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Only grab values that are defined                                                #
			#----------------------------------------------------------------------------------#
			if (defined $self->{$key})
			{
				#----------------------------------------------------------------------------------#
				# Add references (other Simplify objects, ARRAY and HASH only)                     #
				#----------------------------------------------------------------------------------#
				if (ref $self->{$key})
				{
					my $ref = UNMARSHALL($self->{$key});
					if ($ref)
					{
						$data->{$key} = $ref;
					}
				}
				#----------------------------------------------------------------------------------#


				#----------------------------------------------------------------------------------#
				# Add scalars                                                                      #
				#----------------------------------------------------------------------------------#
				else
				{
					$data->{$key} = $self->{$key};
				}
				#----------------------------------------------------------------------------------#
			}
			#----------------------------------------------------------------------------------#
		}
		#----------------------------------------------------------------------------------#
	}
	#----------------------------------------------------------------------------------#

	return $data;
}
#########################################||#########################################



###############################|     UnMarshall     |###############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub UNMARSHALL
{
	my $refed = shift;
	my $deref = (ref $refed) ? undef : $refed;

	#----------------------------------------------------------------------------------#
	# HASH                                                                             #
	#----------------------------------------------------------------------------------#
	if (ref $refed eq 'HASH')
	{
		$deref = {};

		foreach my $key (keys %{$refed})
		{
			my $obj = $refed->{$key};

			if (ref $obj)
			{
				$deref->{$key} = UNMARSHALL($obj);
			}
			else
			{
				$deref->{$key} = $obj;
			}
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# ARRAY                                                                            #
	#----------------------------------------------------------------------------------#
	elsif (ref $refed eq 'ARRAY')
	{
		$deref = [];

		foreach my $obj (@{$refed})
		{
			if (ref $obj)
			{
				push(@{$deref}, UNMARSHALL($obj));
			}
			else
			{
				push(@$deref, $obj);
			}
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Simplify enabled                                                                 #
	#----------------------------------------------------------------------------------#
	elsif ((blessed($refed)) && ($refed->can('Simplify')))
	{
		$deref = $refed->Simplify();
	}
	#----------------------------------------------------------------------------------#

	return $deref;
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Common::Simplify - An L<abstract|http://en.wikipedia.org/wiki/Abstract_type> class for common object serialization

=head1 SYNOPSIS

 # In your data access class package
 use parent qw(Common::Simplify);

 # In your data access class constructor
 $self->{Fields} = { Id => 1, Label => 1, Url => 1 };

 # In the script that creates an instance of your class
 my $data = $obj->Simplify();

=head1 DESCRIPTION

C<Simplify> contains a helper method (of the same name) for data serialization. It requires no parameters, but any parameters passed are added to the C<Fields> list described below.

The package that inherits from C<Simplify> should (but is not required to) implement an attribute named C<Fields> that is a hashref (prefered, but could also be an arrayref). Each key in the hashref (or element in the arrayref) should represent either a method that returns a value or another attribute.

The intent of C<Simplify> is to easily add a measure of control to the data serialization process.  It is not intended to do any deserialization.

=head2 Methods

Only public methods are documented.  Use undocumented methods at your own risk.

=over 4

=item C<Simplify()>

When the C<Simplify()> method is called, the C<Fields> list (and any other items passed in as parameters) is traversed. For each element:

=over 1

=item * if a method of that name exists, grab the return value of that method call (when called with no parameters)

=item * if there is no method of that name, or if the method returns no value, try to retrieve the value of an attribute with that name

=back

If the value returned is an arrayref or hashref, they are likewise traversed and any object references (as opposed to arrayref or hashref) found are either removed or, if the referred object also inherits from C<Simplify>, likewise simplified.

I<It is worth noting that any elements that begin with "Is" followed by a capital letter (such as IsActive, but not Isactive or isactive) will be assigned a string value of "true" or "false", depending on the truthiness of the value, instead of the actual value.>

The keys and their values are returned in a data structure suitable to be serialized by any XML, JSON or YAML serializer.

=back

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

None

=cut