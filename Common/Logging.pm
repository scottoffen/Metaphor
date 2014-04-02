package Common::Logging;
our $VERSION = '1.0.0.0';

#########################################||#########################################
#                                                                                  #
# Common::Logging                                                                  #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Time::HiRes;
	use FileHandle;
	use Fcntl qw(:flock);
	use Common::Config;
	use Common::Storage;
	use Data::Dumper;
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT     = qw(FATAL ERROR WARN INFO DEBUG TRACE);
	our $LOGDIR     = GetConfig()->{'logging'}->{'dir'};
	our $CONSOLE    = 0;
	our $KEY        = '_LOGGERS';
	our $FORMATTERS =
	{
		'time'       => "%-26s",
		'ipaddress'  => "%-15s",
		'pid'        => "%-10d",
		'script'     => "%-25s",
		'package'    => "%-25s",
		'subroutine' => "%-25s",
		'line'       => "%-6s",
		'level'      => "%-5s"
	};
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# L O G G I N G   L E V E L   D E F I N I T I O N S                                #
#----------------------------------------------------------------------------------#
# OFF   : Highest possible rank and is intended to turn off logging                #
# FATAL : Severe error that cause premature termination                            #
# ERROR : Runtime error or unexpected conditions                                   #
# WARN  : Runtime situation is undesirable or unexpected, not necessarily wrong    #
# INFO  : Message highlights the progress of the application                       #
# DEBUG : Detailed information on the flow through the system                      #
# TRACE : Finer-grained informational events than the DEBUG                        #
# ALL   : The lowest possible rank and is intended to turn on all logging          #
#----------------------------------------------------------------------------------#
our $LEVELS = do
{
	my $levels = { 'OFF' => 0, '0' => 'OFF' };

	for (my $i = 0; $i < scalar @EXPORT; $i += 1)
	{
		$levels->{$i+1} = $EXPORT[$i];
		$levels->{$EXPORT[$i]} = $i+1;
	}

	$levels->{'ALL'} = (scalar keys %$levels) / 2;
	$levels->{$levels->{'ALL'}} = 'ALL';

	$levels;
};
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Module Cleanup                                                                   #
#----------------------------------------------------------------------------------#
END
{
	foreach my $key (keys %{$ENV{$KEY}})
	{
		close $ENV{$KEY}->{$key}->{'fh'};
	}
}
#----------------------------------------------------------------------------------#


##################################|     _Log     |##################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub _Log
{
	my $details = shift;

	if (ref $details->{message})
	{
		$details->{message} = Dumper($details->{message});
	}
	$details->{message} =~ s/[\r\n]/ /g;

	#----------------------------------------------------------------------------------#
	# Generate message                                                                 #
	#----------------------------------------------------------------------------------#
	my ($message, $console);
	{
		my (@message, @console);
		foreach my $part ('time', 'ipaddress', 'pid', 'script', 'package', 'subroutine', 'line', 'level', 'message')
		{
			$details->{$part} = '' unless (defined $details->{$part});
			push(@message, $details->{$part});
			push(@console, (exists $FORMATTERS->{$part}) ? sprintf($FORMATTERS->{$part}, $details->{$part}) : $details->{$part});
			# Adds formatting to the console output
		}

		$message = join(',' , @message) . "\n";
		$console = join("\t", @console) . "\n";

		print "$console" if ($CONSOLE);
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Send generated message to all files that accept this log level                   #
	#----------------------------------------------------------------------------------#
	foreach my $key (keys %{$ENV{$KEY}})
	{
		my $logger = $ENV{$KEY}->{$key};

		if ($logger->{'level'} >= $LEVELS->{$details->{level}})
		{
			flock($logger->{'fh'}, LOCK_EX);
			$logger->{'fh'}->print($message);
			flock($logger->{'fh'}, LOCK_UN);
		}
	}
	#----------------------------------------------------------------------------------#
}
#########################################||#########################################



##################################|     FATAL     |#################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub FATAL
{
	my $details = GetDetails();

	$details->{'message'} = shift;
	$details->{'level'}   = 'FATAL';

	_Log($details);
}
#########################################||#########################################



##################################|     ERROR     |#################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub ERROR
{
	my $details = GetDetails();

	$details->{'message'} = shift;
	$details->{'level'}   = 'ERROR';

	_Log($details);
}
#########################################||#########################################



##################################|     WARN     |##################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub WARN
{
	my $details = GetDetails();

	$details->{'message'} = shift;
	$details->{'level'}   = 'WARN';

	_Log($details);
}
#########################################||#########################################



##################################|     INFO     |##################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub INFO
{
	my $details = GetDetails();

	$details->{'message'} = shift;
	$details->{'level'}   = 'INFO';

	_Log($details);
}
#########################################||#########################################



##################################|     DEBUG     |#################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub DEBUG
{
	my $details = GetDetails();

	$details->{'message'} = shift;
	$details->{'level'}   = 'DEBUG';

	_Log($details);
}
#########################################||#########################################



##################################|     TRACE     |#################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub TRACE
{
	my $details = GetDetails();

	$details->{'message'} = shift;
	$details->{'level'}   = 'TRACE';

	_Log($details);
}
#########################################||#########################################



################################|     Console     |#################################
# Public Static                                                                    #
# 0 : 1|0 (optional)                                                               #
#----------------------------------------------------------------------------------#
sub Console
{
	my $class = shift;
	my $value = (scalar @_ > 0) ? shift : undef;

	if (defined $value)
	{
		$CONSOLE = $value;
	}

	return $CONSOLE;
}
#########################################||#########################################



###############################|     ConsoleOff     |###############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub ConsoleOff
{
	$CONSOLE = 0;
}
#########################################||#########################################



################################|     ConsoleOn     |###############################
# Public Static                                                                    #
#----------------------------------------------------------------------------------#
sub ConsoleOn
{
	$CONSOLE = 1;
}
#########################################||#########################################



#############################|     GetCurrentTime     |#############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetCurrentTime
{
	my @time = localtime();
	my ($sec, $micro) = Time::HiRes::gettimeofday();

	my @time_parts;
	push (@time_parts, ($time[5] + 1900));
	push (@time_parts, sprintf("%02d", ($time[4] + 1)));
	push (@time_parts, sprintf("%02d", $time[3]));
	push (@time_parts, join (":", (sprintf("%02d", $time[2]), sprintf("%02d", $time[1]), sprintf("%02d", $time[0]))));
	push (@time_parts, sprintf("%06d", $micro));

	return join(" ", @time_parts);
}
#########################################||#########################################



###############################|     GetDetails     |###############################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GetDetails
{
	my $caller  = 1;
	my $details =
	{
		ipaddress => ($ENV{'REMOTE_ADDR'}) ? $ENV{'REMOTE_ADDR'} : 'local',
		time      => GetCurrentTime(),
		pid       => $$
	};

	while ($caller)
	{
		my @caller = caller($caller);

		#----------------------------------------------------------------------------------#
		# Caller(1) will provide package and line number and defaults for script and sub   #
		#----------------------------------------------------------------------------------#
		if (($caller[3]) && ($caller[3] =~ /^Common::Logging/i))
		{
			$details->{package}    = $caller[0];
			$details->{script}     = GetFileName($caller[1]);
			$details->{line}       = $caller[2];

			$caller++;
			next;
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Caller(2) will provide subroutine                                                #
		#----------------------------------------------------------------------------------#
		unless (defined $details->{subroutine})
		{
			$details->{subroutine} = $caller[3];
			if ($details->{subroutine})
			{
				$details->{subroutine} =~ s/$details->{package}:://i;
			}
		}
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# Caller(2,3) will provide script                                                  #
		#----------------------------------------------------------------------------------#
		$details->{script}  = GetFileName($caller[1]) if (defined $caller[1]);
		$caller = ((($details->{script}) && ($details->{script} =~ /\.pm$/i)) || ($caller <= 2)) ? $caller + 1 : 0;
		#----------------------------------------------------------------------------------#
	}

	$details->{subroutine} = 'inline' unless (defined $details->{subroutine});
	return $details;
}
#########################################||#########################################



################################|     StartLog     |################################
# Public Static                                                                    #
# 0 : { file, path, level }                                                        #
#----------------------------------------------------------------------------------#
sub StartLog
{
	$ENV{$KEY}  = {} unless (defined $ENV{$KEY});

	my $class   = shift();
	my $params  = ((@_) && (ref $_[0] eq 'HASH')) ? shift : undef;
	my $error   = "!Log path undefined";

	if ($LOGDIR)
	{
		$error = CreateFolder($LOGDIR);

		unless ($error =~ /^!/)
		{
			$error = undef;

			my $tfile = GetFileName($ENV{SCRIPT_FILENAME});
			$tfile = ($tfile) ? $tfile . ".txt" : "temp.txt";

			$params->{'file'}    = $tfile unless (defined $params->{'file'});
			$params->{'path'}    = join('/', ($LOGDIR, $params->{'file'})) unless (defined $params->{'path'});
			$params->{'level'}   = 'ALL' unless (defined $params->{'level'});
			$params->{'level'}   = $LEVELS->{$params->{'level'}} unless ($params->{'level'} =~ /^\d+$/);

			return $params->{'path'} if (exists $ENV{$KEY}->{$params->{'path'}});


			$params->{'fh'} = new FileHandle(">> " . $params->{'path'}) || ($error = "!" . $!);

			unless ($error)
			{
				$ENV{$KEY}->{$params->{'path'}} = $params;
				return $params->{'path'};
			}
		}
	}

	return $error;
}
#########################################||#########################################



#################################|     StopLog     |################################
# Public Static                                                                    #
# 0 : path (as returned by StartLog)                                               #
#----------------------------------------------------------------------------------#
sub StopLog
{
	my $class = shift;
	my $path  = shift;

	if (($path) && (defined $ENV{$KEY}->{$path}))
	{
		close $ENV{$KEY}->{$path}->{'fh'};
		delete $ENV{$KEY}->{$path};
	}
}
#########################################||#########################################



1;
