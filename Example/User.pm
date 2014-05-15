package Example::User;
our $VERSION = '1.0';

#########################################||#########################################
#                                                                                  #
# Example::User                                                                    #
# © Copyright Information and Link To Authors Site Goes Here                       #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use Common::Database;
	use Common::Encryption qw(:all);
	use Common::Logging;
	use Common::Util;
	use Scalar::Util qw(blessed);
	use parent qw(Common::Simplify);
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $TABLE  = 'Users';
	our $FIELDS = "$TABLE.Id, $TABLE.FirstName, $TABLE.LastName, $TABLE.Email, $TABLE.Password, $TABLE.Salt, $TABLE.IsActive";
	our $GUID   = '[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}';
	our $EMAIL  = '[a-z0-9._%+-]+@(?:[a-z0-9-]+\.)+[a-z]{2,4}';
	our $BOOL   = '(1|0)';
	our $NAME   = '.{1,50}';
#----------------------------------------------------------------------------------#


##################################|     new     |###################################
sub new
{
	my $class = shift;
	my ($error, $valid, @missing);

	#----------------------------------------------------------------------------------#
	# Initialize the object                                                            #
	#----------------------------------------------------------------------------------#
	my $self  =
	{
		#----------------------------------------------------------------------------------#
		# These represent the fields for a given row of data (or variations of them, such  #
		# as raw unix dates vs formatted dates). Provide defaults values as appropriate.   #
		#----------------------------------------------------------------------------------#
		'Id'        => undef,
		'FirstName' => undef,
		'LastName'  => undef,
		'Email'     => undef,
		'Password'  => undef,
		'Salt'      => undef,
		'IsActive'  => 1,
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# This keeps track of changes to the fields that are allowed to have their values  #
		# change.  If a field is immutable, omit it from this list. A true value (1) means #
		# that a field has changed while a false value(0) means the field has not.         #
		#----------------------------------------------------------------------------------#
		'Changes'   =>
		{
			'FirstName' => 0,
			'LastName'  => 0,
			'Email'     => 0,
			'Password'  => 0,
			'Salt'      => 0,
			'IsActive'  => 0
		},
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# The Fields hasref is specifically used for implementing Simplify, but we also    #
		# use the value to indicate whether a value for that field is required for object  #
		# instantiation. A true value (1) means it is required.                            #
		#----------------------------------------------------------------------------------#
		'Fields'    =>
		{
			'Id'        => 0,
			'FirstName' => 1,
			'LastName'  => 1,
			'Email'     => 1,
			'IsActive'  => 0
		},
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# I find it handy to have a validator available for each field, so it is easy to   #
		# consistently check the value being assigned to a field.                          #
		#----------------------------------------------------------------------------------#
		'Validator'    =>
		{
			'Id'        => qr{^$GUID$}i,
			'FirstName' => qr{^$NAME$},
			'LastName'  => qr{^$NAME$},
			'Email'     => qr{^$EMAIL$}i,
			'IsActive'  => qr{^$BOOL$}
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

				($self->{Id}, $self->{FirstName}, $self->{LastName}, $self->{Email}, $self->{Password}, $self->{Salt}, $self->{IsActive}) = @{$_[0]};
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

				if (defined $self->{Password})
				{
					($self->{Password}, $self->{Salt}) = Encrypt($self->{Password}) unless (defined $self->{Salt});
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
					($self->{Id}, $self->{FirstName}, $self->{LastName}, $self->{Email}, $self->{Password}, $self->{Salt}, $self->{IsActive}) = @$values;
					$valid = 1;
				}
			}
			#----------------------------------------------------------------------------------#


			#----------------------------------------------------------------------------------#
			# Fetch data from database using alternate method                                  #
			#----------------------------------------------------------------------------------#
			elsif (scalar @_ == 2)
			{
				my ($email, $password) = @_;
				$error = "Invalid username or password ($email)";
				my $values = Fetch("select $FIELDS from $TABLE where $TABLE.Email = ?", [$email]);

				if ((ref $values eq 'ARRAY') && (IsGuid($$values[0])))
				{
					($self->{Id}, $self->{FirstName}, $self->{LastName}, $self->{Email}, $self->{Password}, $self->{Salt}, $self->{IsActive}) = @$values;
					$valid = Matches($password, $self->{Salt}, $self->{Password});
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



################################|     FirstName     |###############################
sub FirstName
{
	my ($self, $value) = @_;
	if ((defined $value) && ($value ne $self->{FirstName}) && ($value =~ $self->{Validator}->{FirstName}))
	{
		$self->{FirstName} = $value;
		$self->{Changes}->{FirstName} = 1;
	}
	return $self->{FirstName};
}
#########################################||#########################################



################################|     LastName     |################################
sub LastName
{
	my ($self, $value) = @_;
	if ((defined $value) && ($value ne $self->{LastName}) && ($value =~ $self->{Validator}->{LastName}))
	{
		$self->{LastName} = $value;
		$self->{Changes}->{LastName} = 1;
	}
	return $self->{LastName};
}
#########################################||#########################################



##################################|     Email     |#################################
sub Email
{
	my ($self, $value) = @_;
	if ((defined $value) && ($value ne $self->{Email}) && ($value =~ $self->{Validator}->{Email}))
	{
		$self->{Email} = $value;
		$self->{Changes}->{Email} = 1;
	}
	return $self->{Email};
}
#########################################||#########################################



################################|     Password     |################################
sub Password
{
	my ($self, $value) = @_;

	if (defined $value)
	{
		if ($self->{Password})
		{
			unless (Matches($value, $self->{Salt}, $self->{Password}))
			{
				($self->{Password}, $self->{Salt}) = Encrypt($value);
				$self->{Password}->{Changes} = 1;
				$self->{Salt}->{Changes} = 1;
			}
		}
		else
		{
			($self->{Password}, $self->{Salt}) = Encrypt($value);
			$self->{Password}->{Changes} = 1;
			$self->{Salt}->{Changes} = 1;
		}
	}

	return (defined $self->{Password}) ? 1 : 0;
}
#########################################||#########################################



################################|     IsActive     |################################
sub IsActive
{
	my ($self) = @_;
	return $self->{IsActive};
}
#########################################||#########################################



################################|     Activate     |################################
sub Activate
{
	my ($self) = @_;
	$self->{IsActive} = 1;
	$self->{Changes}->{IsActive} = 1;
}
#########################################||#########################################



###############################|     Deactivate     |###############################
sub Dectivate
{
	my ($self) = @_;
	$self->{IsActive} = 0;
	$self->{Changes}->{IsActive} = 1;
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

		$query = (scalar @changes > 0) ? "update $TABLE set " . (join(', ', @changes)) . " where Id = ?" : undef;
		if ($query)
		{
			push (@bindings, $self->{Id});
			$result = Execute($query, \@bindings);
		}
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# SQL : Insert                                                                     #
	#----------------------------------------------------------------------------------#
	if ($result == 0)
	{
		unless (defined $self->{Id})
		{
			$self->{Id} = (IsGuid($newid)) ? $newid : ((defined $self->{NewId}) && (IsGuid($self->{NewId}))) ? $self->{NewId} : CreateGuid();
		}

		@bindings = ();
		my (@keys, @values);

		foreach my $key (keys %{$self->{Changes}})
		{
			push (@keys, $key);
			push (@values, '?');
			push (@bindings, $self->{$key});

			$self->{Changes}->{$key} = 0;
		}

		$query = (scalar @keys > 0) ? "insert into $TABLE (Id, " . (join(', ', @keys)) . ") values (?, " . (join(', ', @values)) . ")" : undef;

		if ($query)
		{
			unshift(@bindings, $self->{Id});
			$result = Execute($query, \@bindings);
		}
	}
	#----------------------------------------------------------------------------------#

	#----------------------------------------------------------------------------------#
	# Post execution actions
	#----------------------------------------------------------------------------------#
	if ($result)
	{
		#--> post success actions, if any
		#--> for insert vs update:
		# if ($query =~ /^insert/i)
	}
	else
	{
		#--> post failure actions, if any
	}
	#----------------------------------------------------------------------------------#

	return $result;
}
#########################################||#########################################



#################################|     Delete     |#################################
sub Delete
{
	my ($self) = @_;
	my $result = Execute("delete from $TABLE where Id = ?", [$self->{Id}]);

	if ($result)
	{
		#--> post-delete success actions, if any
	}
	else
	{
		#--> post-delete failure actions, if any
	}

	return $result;
}
#########################################||#########################################



###################################|     Get     |##################################
sub Get
{
	my ($class, $params) = @_;

	$class = blessed($class) if (ref $class);

	my @list     = List($params);
	my @results  = map {$class->new($_)} @list;

	return (wantarray) ? @results : (defined wantarray) ? \@results : undef;
}
#########################################||#########################################



##################################|     List     |##################################
sub List
{
	my ($params) = Declassify(\@_, __PACKAGE__);
	my @results;

	$params = { type => 'active' } unless (ref $params eq 'HASH');
	{
		my ($fields, @tables, @conditions, @orderby, $query, @bindings);

		#----------------------------------------------------------------------------------#
		# Define base query                                                                #
		#----------------------------------------------------------------------------------#
		$fields = $FIELDS;
		push (@tables, $TABLE);
		push (@orderby, "$TABLE.LastName");
		push (@orderby, "$TABLE.FirstName");
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Search Types                                                                     #
		# For a given type you can add conditions, tables and bindings and order-by.       #
		#----------------------------------------------------------------------------------#
		if (exists $params->{type})
		{
			if (lc($params->{type}) eq 'active')
			{
				push (@conditions, "$TABLE.IsActive = true");
			}
			elsif (lc($params->{type}) eq 'inactive')
			{
				push (@conditions, "$TABLE.IsActive = false");
			}
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Set default search options and build query here                                  #
		#----------------------------------------------------------------------------------#
		$query = "select $fields\nfrom " . join(', ', @tables) . "\nwhere " . join("\n and ", @conditions) . "\norder by " . join(', ', @orderby);
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
			@$record{qw(Id FirstName LastName Email Password Salt IsActive)} = @$row;
			push(@results, $record);
		}
		#----------------------------------------------------------------------------------#
	}

	return (wantarray) ? @results : (defined wantarray) ? \@results : undef;
}
#########################################||#########################################

1;

__END__

This is the table used to store user information for this data element.

CREATE TABLE IF NOT EXISTS `Users` (
  `Id` CHAR(36) NOT NULL,
  `FirstName` CHAR(50) NOT NULL,
  `LastName` CHAR(50) NOT NULL,
  `Email` CHAR(255) NOT NULL,
  `Password` CHAR(60) NOT NULL,
  `Salt` CHAR(22) NOT NULL,
  `IsActive` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`Id`),
  UNIQUE INDEX `Email_UNIQUE` (`Email` ASC))
ENGINE = InnoDB