package Common::Database;
our $VERSION = '1.0.0.0';

#########################################||#########################################
#                                                                                  #
# Common::Database                                                                 #
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
	use Common::Config;
	use Common::Logging;
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT = qw(Fetch Execute Salt);
	our $CONFIG = GetConfig()->{'database'};
	our @ERRORS = ();
	our $DEF    = 'default';
	our $KEY    = '_DBH';
	$ENV{$KEY}  = {};
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Module Cleanup                                                                   #
#----------------------------------------------------------------------------------#
END
{
	foreach my $key (keys %{$ENV{$KEY}})
	{
		$ENV{$KEY}->{$key}->disconnect();
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
	my $database = (scalar @_ > 0) ? shift : $DEF;
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
					$ENV{$KEY}->{$database} = $dbh;
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

	return undef;
}
#########################################||#########################################



#################################|     Execute     |################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub Execute
{
	my $query    = (scalar @_ > 0) ? shift : undef;
	my $bindings = ((scalar @_ > 0) && (ref $_[0] eq 'ARRAY')) ? shift : [];
	my $database = (scalar @_ > 0) ? shift : undef;

	if ($query)
	{
		my $dbh = GetConnection($database);

		if ($dbh)
		{
			DEBUG("Query    : $query");
			DEBUG("Bindings : " . join(", ", @$bindings));

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
	my $query    = (scalar @_ > 0) ? shift : undef;
	my $bindings = ((scalar @_ > 0) && (ref $_[0] eq 'ARRAY')) ? shift : [];
	my $database = (scalar @_ > 0) ? shift : undef;

	if ($query)
	{
		my $dbh = GetConnection($database);

		if ($dbh)
		{
			DEBUG("Query    : $query");
			DEBUG("Bindings : " . join(", ", @$bindings));

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
				if ((scalar @rows > 1) || (wantarray))
				{
					return @rows;
				}
				elsif (scalar @rows == 1)
				{
					return $rows[0];
				}
			}
		}
		else
		{
			WARN("Unable to execute query : ($query), (" . join(", ", @$bindings) . ")");
		}
	}

	return undef;
}
#########################################||#########################################



#############################|     GetConnection     |##############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetConnection
{
	my $database = ((scalar @_ > 0) && (defined $_[0])) ? shift : $DEF;

	if (exists $ENV{$KEY}->{$database})
	{
		return $ENV{$KEY}->{$database};
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
	return pop(@ERRORS);
}
#########################################||#########################################



############################|     RemoveConnection     |############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub RemoveConnection
{
	my $class = shift;
	my $value = ((scalar @_ > 0) & (defined $_[0])) ? shift : undef;

	if ((defined $value) && ($DEF ne $value) && (exists $CONFIG->{$value}))
	{
		delete $CONFIG->{$value};
		if (exists $ENV{$KEY}->{$value})
		{
			close $ENV{$KEY}->{$value};
			delete $ENV{$KEY}->{$value};
		}
	}
}
#########################################||#########################################



##################################|     Salt     |##################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub Salt
{
	my $class = shift;
	my $value = ((scalar @_ > 0) && (defined $_[0])) ? shift : $DEF;

	if ((defined $value) && (defined $CONFIG->{$value}))
	{
		return (defined $CONFIG->{$value}->{salt}) ? $CONFIG->{$value}->{salt} : undef;
	}

	return undef;
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
		$DEF = $value;
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