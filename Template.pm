package Template;
our $VERSION = '1.0';

#########################################||#########################################
#                                                                                  #
# Template                                                                         #
# © Copyright YYYY Copyright Holder                                                #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use Metaphor::Database;
	use Metaphor::Logging;
	use Metaphor::Util;
	use Scalar::Util qw(blessed);
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $TABLE  = 'TableName';
	our @FIELDS = qw(Id );
	our $FIELDS = join(', ', map{ "$TABLE.$_" } @FIELDS);
	our $GUID   = '[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}';
	our $BOOL   = '(1|0|true|false)';
	our $TEXT   = '.{1,50}';
#----------------------------------------------------------------------------------#


##################################|     new     |###################################
sub new
{
	my $class = shift;
	my ($error, $valid, @missing);

	#----------------------------------------------------------------------------------#
	# Initialize the object                                                            #
	#----------------------------------------------------------------------------------#
	my $self =
	{
		#----------------------------------------------------------------------------------#
		# These represent the fields for a given row of data (or variations of them, such  #
		# as raw unix dates vs formatted dates). Provide default values as appropriate.    #
		#----------------------------------------------------------------------------------#
		'Id'      => undef,
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# This is used to create insert and update queries, so include here all values you #
		# would want used in those. Don't include the unique id, if any, as either you or  #
		# mysql will be creating it and it won't likely ever need to change. A true value  #
		# (1) means that a field has changed and a false value(0) means the field has not. #
		#----------------------------------------------------------------------------------#
		'Changes' =>
		{
		},
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# The Fields hasref is specifically used for implementing Simplify, but we also    #
		# use the value to indicate whether a value for that field is required for object  #
		# instantiation. A true value (1) means it is required.                            #
		#----------------------------------------------------------------------------------#
		'Fields'  =>
		{
		},
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# I find it handy to have a validator available for each field, so it is easy to   #
		# consistently check the value being assigned to a field.                          #
		#----------------------------------------------------------------------------------#
		'Validator' =>
		{
			'Id'    => qr{^$GUID$}i
		}
		#----------------------------------------------------------------------------------#
	};
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Unmarshal incoming parameters                                                    #
	#----------------------------------------------------------------------------------#
	if (@_)
	{
		#----------------------------------------------------------------------------------#
		# If a hashref or an arrayref is the first parameter, then it is expected that it  #
		# contains all the values we need to create the data element.                      #
		#----------------------------------------------------------------------------------#
		if (ref $_[0])
		{
			#----------------------------------------------------------------------------------#
			# Set the field values based on corresponding values from a hashref                #
			#----------------------------------------------------------------------------------#
			if (ref $_[0] eq 'HASH')
			{
				my %params = %{$_[0]};
				$error     = "Required values not found in hashref";
				$valid     = 1;

				foreach my $key (keys %params)
				{
					$self->{$key} = $params{$key} if (defined $params{$key});
				}
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Set the field values based on ordered values from an arrayref                    #
			#----------------------------------------------------------------------------------#
			elsif (ref $_[0] eq 'ARRAY')
			{
				my @values = @{$_[0]};
				$error     = "Required values not found in arrayref";
				$valid     = 1;

				@$self{@FIELDS} = @{$_[0]};
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Now validate that the required values have been assigned.  You only need to do   #
			# this if you didn't get the data from the database directly.                      #
			#----------------------------------------------------------------------------------#
			if ($valid)
			{
				foreach my $key (%{$self->{Fields}})
				{
					if (defined $self->{$key})
					{
						if ($self->{Validator}->{$key})
						{
							my $pattern = $self->{Validator}->{$key};
							unless ($self->{$key} =~ $pattern)
							{
								$valid = 0;
								push (@missing, "$key : Bad value (" . $self->{$key} . ")");
							}
						}
					}
					elsif ($self->{Fields}->{$key})
					{
						$valid = 0;
						push (@missing, "$key : Not defined");
					}
				}
			}
			#----------------------------------------------------------------------------------#
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# If the first parameter is not a hashref, then we want to use the incoming data   #
		# to find a corresponding element in the database. Here are two different ways.    #
		#----------------------------------------------------------------------------------#
		else
		{
			#----------------------------------------------------------------------------------#
			# Fetch data from the database for a specific element by passing the elements GUID #
			#----------------------------------------------------------------------------------#
			if (IsGuid($_[0]))
			{
				$error = "Record $_[0] not found in table $TABLE";
				my $values = Fetch("select $FIELDS from $TABLE where Id = ?", [$_[0]]);

				if ((ref $values eq 'ARRAY') && ($$values[0] eq $_[0]))
				{
					@$self{@FIELDS} = @$values;
					$valid = 1;
				}
			}
			#----------------------------------------------------------------------------------#
		}
		#----------------------------------------------------------------------------------#
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
		DEBUG($error . " " . join(', ', @missing));
		return undef;
	}
	#----------------------------------------------------------------------------------#
}
#########################################||#########################################



###################################|     Id     |###################################
sub Id
{
	my ($self) = @_;
	return $self->{Id};
}
#########################################||#########################################



##################################|     Name     |##################################
sub Name
{
	my ($self, $value) = @_;

	if ((defined $value) && ($value ne $self->{Name}))
	{
		if ((!defined $self->{Validator}->{Name}) || ($value =~ $self->{Validator}->{Name}))
		{
			$self->{Name} = $value;
			$self->{Changes}->{Name} = 1;
		}
	}
	return $self->{Name};
}
#########################################||#########################################



##################################|     Save     |##################################
sub Save
{
	my ($self, $newid) = @_;
	my $result = 0;
	my ($query, @bindings);

	#----------------------------------------------------------------------------------#
	# SQL : Update                                                                     #
	#----------------------------------------------------------------------------------#
	if ($self->{Id})
	{
		my @changes;

		foreach my $key (keys %{$self->{Changes}})
		{
			if ($self->{Changes}->{$key})
			{
				push (@changes, "$key = ?");
				push (@bindings, $self->{$key});
				$self->{Changes}->{$key} = 0;
			}
		}

		if (scalar @changes > 0)
		{
			push (@bindings, $self->{Id});
			$query  = "update $TABLE set " . (join(', ', @changes)) . " where Id = ?"
			$result = Execute($query, \@bindings);
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# SQL : Insert                                                                     #
	#----------------------------------------------------------------------------------#
	if ($result == 0)
	{
		$self->{Id} = (IsGuid($newid)) ? $newid : (IsGuid($self->{NewId})) ? $self->{NewId} : CreateGuid();
		@bindings   = ();

		my (@keys, @values);

		foreach my $key (keys %{$self->{Changes}})
		{
			push (@keys, $key);
			push (@values, '?');
			push (@bindings, $self->{$key});

			$self->{Changes}->{$key} = 0;
		}

		if (scalar @keys > 0)
		{
			unshift(@bindings, $self->{Id});
			$query  = "insert into $TABLE (Id, " . (join(', ', @keys)) . ") values (?, " . (join(', ', @values)) . ")";
			$result = Execute($query, \@bindings);
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Post execution actions                                                           #
	#----------------------------------------------------------------------------------#
	if ($result)
	{
		#--> Success post execution actions
		#--> To segregate actions based on insert or update:
		#--> if ($query =~ /^insert/i)
	}
	else
	{
		#--> Failure post execution actions
		#--> To segregate actions based on insert or update:
		#--> if ($query =~ /^update/i)
	}
	#----------------------------------------------------------------------------------#

	return $result;
}
#########################################||#########################################



#################################|     Delete     |#################################
sub Delete
{
	my ($self) = @_;
	my $result = Execute("delete from $TABLE where Id = ?", [ $self->{Id} ]);

	#----------------------------------------------------------------------------------#
	# Post execution actions                                                           #
	#----------------------------------------------------------------------------------#
	if ($result)
	{
		#--> Success post delete actions, if any
	}
	else
	{
		#--> Failure post delete actions, if any
	}
	#----------------------------------------------------------------------------------#

	return $result;
}
#########################################||#########################################



###################################|     Get     |##################################
sub Get
{
	my ($class, $params) = @_;

	$class = blessed($class) if (ref $class);

	my @list = List($params);
	my @results = map {$class->new($_)} @list;

	return (wantarray) ? @results : (defined wantarray) ? \@results : undef;
}
#########################################||#########################################



##################################|     List     |##################################
sub List
{
	my ($params) = Declassify(\@_, __PACKAGE__);
	my @results;

	$params = {} unless (ref $params eq 'HASH');
	{
		my ($fields, @fields, @tables, @conditions, @orderby, $query, @bindings);

		#----------------------------------------------------------------------------------#
		# Define base query                                                                #
		#----------------------------------------------------------------------------------#
		$fields = $FIELDS;
		@fields = @FIELDS;
		push (@tables, $TABLE);
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Search Types                                                                     #
		# For a given type you can add conditions, tables and bindings and order-by.       #
		#----------------------------------------------------------------------------------#
		if (exists $params->{type})
		{
			#--> Add filters based on params hashref
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Set default search options and build query here                                  #
		#----------------------------------------------------------------------------------#
		$query = "select $fields\nfrom " . join(', ', @tables) . "\nwhere " . join("\n  and ", @conditions) . "\norder by " . join(', ', @orderby);
		$query =~ s/\nwhere \norder by/\norder by/i;
		$query =~ s/\norder by $//i;
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Execute the query and build the result set                                       #
		#----------------------------------------------------------------------------------#
		my @data = Fetch($query, \@bindings);
		foreach my $row (@data)
		{
			my $record = {};
			@$record{@FIELDS} = @$row;
			push(@results, $record);
		}
		#----------------------------------------------------------------------------------#
	}

	return (wantarray) ? @results : (defined wantarray) ? \@results : undef;
}
#########################################||#########################################



1;

__END__

Include the table definition used by this module here

=pod

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Methods

=over 12

=item C<method(PARAMS)>

=back

=head1 BUGS

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT

=head1 AVAILABILITY

=head1 AUTHOR

=head1 SEE ALSO

=cut
