package Metaphor::Database;

#########################################||#########################################
#                                                                                  #
# Metaphor::Database                                                               #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use DBI;
	use MIME::Base64;
	use Metaphor::Config;
	use Metaphor::Logging;
	use Metaphor::Util qw(Declassify);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $VERSION   = '1.0.0';
	our $DBHANDLES = {};
	our @EXPORT    = qw(Fetch Execute);
	our $CONFIG    = GetConfig()->{'database'};
	our @ERRORS    = ();
	our $DEFAULT   = 'default';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Module Cleanup                                                                   #
#----------------------------------------------------------------------------------#
END
{
	foreach my $key (keys %{$DBHANDLES})
	{
		$DBHANDLES->{$key}->disconnect();
	}
}
#----------------------------------------------------------------------------------#


##############################|     AddConnection     |#############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub AddConnection
{
	my $class  = shift;
	my $params = ((scalar @_ > 0) & (ref $_[0] eq 'HASH')) ? shift : undef;

	if ($params)
	{
		unless (exists $params->{id})
		{
			$params->{id} = join("-", (time, $$));
		}

		if (VerifyDbParams($params->{id}, $params))
		{
			$CONFIG->{$params->{id}} = $params;
		}
	}

	return $params->{id};
}
#########################################||#########################################



################################|     Connect     |#################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub Connect
{
	my $database = (scalar @_ > 0) ? shift : $DEFAULT;
	my $params   = (exists $CONFIG->{$database}) ? $CONFIG->{$database} : (ref $database eq 'HASH') ? $database : undef;

	if (ref $database eq 'HASH')
	{
		$database = (exists $params->{id}) ? $params->{id} : join("-", (time, $$));
	}

	if ($params)
	{
		if (VerifyDbParams($database, $params))
		{
			#----------------------------------------------------------------------------------#
			# Connect to the database                                                          #
			#----------------------------------------------------------------------------------#
			{
				my $con = join(":", ("dbi", "mysql", $params->{schema}, $params->{host}));
				my $dbh = DBI->connect($con, $params->{username}, decode_base64($params->{password}), {RaiseError => 0, PrintError => 0});

				if ($DBI::err)
				{
					ERROR("Connection Failure: " . $DBI::err . " : " . $DBI::errstr);
					ERROR("Connection String: $con");
				}
				else
				{
					$DBHANDLES->{$database} = $dbh;
					return $dbh;
				}
			}
			#----------------------------------------------------------------------------------#
		}
	}
	else
	{
		ERROR("No connection parameters found for $database");
	}

	ERROR("No connection available for $database");

	return;
}
#########################################||#########################################



#################################|     Execute     |################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub Execute
{
	my @params   =  Declassify(\@_, __PACKAGE__);
	my $query    = (scalar @params > 0) ? shift(@params) : undef;
	my $bindings = ((scalar @params > 0) && (ref $params[0] eq 'ARRAY')) ? shift(@params) : [];
	my $database = (scalar @params > 0) ? shift(@params) : undef;

	if ($query)
	{
		my $dbh = GetConnection($database);

		if ($dbh)
		{
			{
				# because sometimes there are no bindings
				no warnings 'uninitialized';
				DEBUG("Query    : $query");
				DEBUG("Bindings : " . join(", ", @$bindings));
			}

			my $sth = $dbh->prepare($query);

			if ($sth)
			{
				my $result = $sth->execute(@$bindings);

				if ($result)
				{
					return ($result eq '0E0') ? 0 : $result;
				}
			}

			if ($dbh->errstr)
			{
				my $error = join(':', ($dbh->err, $dbh->errstr));
				push(@ERRORS, $error);
				ERROR($error);
			}
		}
		else
		{
			WARN("Unable to execute query : ($query), (" . join(", ", @$bindings) . ")");
		}
	}

	return 0;
}
#########################################||#########################################



#################################|     Fetch     |##################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub Fetch
{
	my @params   =  Declassify(\@_, __PACKAGE__);
	my $query    = (scalar @params > 0) ? shift(@params) : undef;
	my $bindings = ((scalar @params > 0) && (ref $params[0] eq 'ARRAY')) ? shift(@params) : [];
	my $database = (scalar @params > 0) ? shift(@params) : undef;

	if ($query)
	{
		my $dbh = GetConnection($database);

		if ($dbh)
		{
			{
				# because sometimes there are no bindings
				no warnings 'uninitialized';
				DEBUG("Query    : $query");
				DEBUG("Bindings : " . join(", ", @$bindings));
			}

			my @rows = ();
			my $sth = $dbh->prepare($query);

			if ($sth)
			{
				$sth->execute(@$bindings);

				#--> NOTE: There is a good reason I'm not using fetchrow_arrayref()
				while (my @row = $sth->fetchrow_array())
				{
					my $row = \@row;
					push(@rows, $row);
				}

				$sth->finish();
			}

			if ($dbh->errstr)
			{
				my $error = join(':', ($dbh->err, $dbh->errstr));
				push(@ERRORS, $error);
				ERROR($error);
			}
			else
			{
				if (scalar @rows == 0)
				{
					if (wantarray)
					{
						return ();
					}
					else
					{
						return;
					}
				}
				elsif (wantarray)
				{
					return @rows;
				}
				else
				{
					return (scalar @rows > 1) ? \@rows : $rows[0];
				}
			}
		}
		else
		{
			WARN("Connection error : unable to execute query : ($query)");
		}
	}

	return;
}
#########################################||#########################################



#############################|     GetConnection     |##############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetConnection
{
	my $database = ((scalar @_ > 0) && (defined $_[0])) ? shift : $DEFAULT;

	if (exists $DBHANDLES->{$database})
	{
		return $DBHANDLES->{$database};
	}
	else
	{
		return Connect($database);
	}
}
#########################################||#########################################



##############################|     GetLastError     |##############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub GetLastError
{
	if (scalar @ERRORS > 0)
	{
		return pop(@ERRORS);
	}

	return;
}
#########################################||#########################################



############################|     RemoveConnection     |############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub RemoveConnection
{
	my $class = shift;
	my $value = ((scalar @_ > 0) & (defined $_[0])) ? shift : undef;

	if ((defined $value) && ($DEFAULT ne $value) && (exists $CONFIG->{$value}))
	{
		delete $CONFIG->{$value};
		if (exists $DBHANDLES->{$value})
		{
			close $DBHANDLES->{$value};
			delete $DBHANDLES->{$value};
		}
	}
}
#########################################||#########################################



###############################|     SetDefault     |###############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub SetDefault
{
	my $class = shift;
	my $value = ((scalar @_ > 0) && (defined $_[0])) ? shift : undef;

	if ((defined $value) && (exists $CONFIG->{$value}))
	{
		$DEFAULT = $value;
	}
}
#########################################||#########################################



#############################|     VerifyDbParams     |#############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub VerifyDbParams
{
	my $id     = shift;
	my $params = shift;

	#----------------------------------------------------------------------------------#
	# Verify required parameters have been provided                                    #
	#----------------------------------------------------------------------------------#
	{
		my @required = qw(host schema username password);
		my $missing  = 0;
		my @missing  = ();

		foreach my $key (@required)
		{
			unless ((exists $params->{$key}) && (defined $params->{$key}))
			{
				push (@missing, $key);
				$missing++;
			}
		}

		if ($missing > 0)
		{
			ERROR("Unable to connect to db $id : missing $missing configuration parameters (" . join(', ', @missing) . ").");
			return 0;
		}

		return 1;
	}
	#----------------------------------------------------------------------------------#
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Metaphor::Database - Both a convenience wrapper for executing queries against a MySQL database as well as a way to insulate the rest of the L<Metaphor::Perl|https://github.com/scottoffen/common-perl> framework should I decide to use a different RDBMS in the future.

=head1 SYNOPSIS

In L<config.json|https://github.com/scottoffen/common-perl/wiki/Metaphor::Config>:

 {
 	...
 	"database" :
 	{
 		"default" :
 		{
 			"host"     : "host:port",
 			"schema"   : "schema-name",
 			"username" : "username",
 			"password" : "cGFzc3dvcmQ="
 		}
 	}
 }

In your script:

 use Metaphor::Database; # Exports Fetch and Execute

 my $id = Metaphor::Database->AddConnection(
 {
 	"host"     => "localhost",
 	"schema"   => "my_schema",
 	"username" => "myusername",
 	"password" => "cGFzc3dvcmQ="
 });

 Metaphor::Database->SetDefault($id);

 # Execute returns 0 on failure, number of rows affected on success
 Execute("insert into customers (id, fname, lname), (?, ?, ?)", [1, "Bart", "Simpson"]);

 # Fetch returns an array of array refs
 my @rows = Fetch("select id, fname, lname from customers");

 # Returns the last error and removes it from the array
 my $error0 = Metaphor::Database->GetLastError();

 # A different error is returned this time!
 my $error1 = Metaphor::Database->GetLastError();

=head1 DESCRIPTION

Easily connect to a database using values from your configuration file, or provide credentials on-the-fly. Define a default, or connect to and query multiple databases simultaneously.

Connections are created as needed, so you don't ever need to call any kind of C<Connect()> method.  Created connections are cached, so you won't be reconnecting each time you need to run a query.

=head2 Methods

Only public methods are documented.  Use undocumented methods at your own risk.

=head3 Exported Methods

=over 12

=item C<Execute(QUERY[, BINDINGS, DB])>

 # Execute returns 0 on failure, number of rows affected on success
 Execute("insert into customers (id, fname, lname), (?, ?)", [1, "Bart", "Simpson"]);

BINDINGS is presumed to be an C<ARRAYREF>.  So, if there is a second parameter, and the second parameters isn't an array ref, the second parameter is assumed to be a database id.  If no DB is specified, the default is used.

Executes the QUERY passed in with the BINDINGS provided using the connection specified by DB.  Returns C<0> on failure, on success it returns the number of rows affected.

Any error produced by the connection and execution of the query can be retrieved via C<GetLastError()>.

=item C<Fetch(QUERY[, BINDINGS, DB])>

 # Fetch returns an array of array refs
 my @rows = Fetch("select id, fname, lname from customers");

BINDINGS is presumed to be an C<ARRAYREF>.  So, if there is a second parameter, and the second parameters isn't an array ref, the second parameter is assumed to be a database id.  If no DB is specified, the default is used.

Executes the QUERY passed in with the BINDINGS provided using the connection specified by DB.  Returns the results of the query:

1. If there are multiple rows OR if the return value is expected to be an array, an array (or arrayref) of arrayrefs representing each row is returned.

2. If there is only one value AND the return value is not expected to be an array, only a single arrayref is returned, representing the result.

3. If no rows are returned, returns undef.

Any error produced by the connection and execution of the query can be retrieved via C<GetLastError()>.

=back

=head3 Other Methods

=over 12

=item C<AddConnection(HASHREF)>

 my $id = Metaphor::Database->AddConnection(
 {
 	"id"       => "mydb",
 	"host"     => "localhost",
 	"schema"   => "my_schema",
 	"username" => "myusername",
 	"password" => "cGFzc3dvcmQ="
 });

If successful, C<$id> should contain the string "mydb".  You can pass this value to either C<RemoveConnection()> or C<SetDefault()> to, respectively, remove the connection or set that connection as the default.

You can also pass C<$id> as the last parameter to C<Fetch()> or C<Execute()> to specify that you want to use that connection instead of the default connection.

C<id> is an optional parameter in the hashref.  If omitted, an id will be created and returned.

=item C<GetLastError()>

 # Returns the last error and removes it from the array
 my $error0 = Metaphor::Database->GetLastError();

 # A different error is returned this time!
 my $error1 = Metaphor::Database->GetLastError();

Pops the last value from the array of database connection and/or execution errors and returns it.  Each consecutive call will return a different value (or no value, if there are no errors in the array).

Only connection errors are automatically logged (via C<Metaphor::Logging> using C<WARN()>).

=item C<RemoveConnection(DB)>

Removes the connection specified by DB - unless it is the default!

=item C<SetDefault(DB)>

If DB is an id that refers to a connection configuration, that connection configuration is now the default, and will be used in all calls to C<Fetch()> and C<Execute()> when a DB is not provided.

=back

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

=over 1

=item * L<Metaphor::Config|https://github.com/scottoffen/common-perl/wiki/Metaphor::Config>

=item * L<Metaphor::Logging|https://github.com/scottoffen/common-perl/wiki/Metaphor::Logging>

=item * L<Metaphor::Util|https://github.com/scottoffen/common-perl/wiki/Metaphor::Util>

=cut
