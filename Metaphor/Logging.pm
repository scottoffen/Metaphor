package Metaphor::Logging;
our $VERSION = '1.0.0';

#########################################||#########################################
#                                                                                  #
# Metaphor::Logging                                                                #
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
	use Metaphor::Config;
	use Metaphor::Storage;
	use Metaphor::Util qw(Declassify);
	use Data::Dumper;
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our @EXPORT     = qw(FATAL ERROR WARN INFO DEBUG TRACE);
	our $LOGDIR     = (GetConfig()->{'logging'}) ? GetConfig()->{'logging'}->{'dir'} : undef;
	our $CONSOLE    = 0;
	our $LOGGERS    = {};
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

	our %EXPORT_TAGS =
	(
		'all' => [qw(FATAL ERROR WARN INFO DEBUG TRACE)]
	);
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
	foreach my $key (keys %{$LOGGERS})
	{
		close $LOGGERS->{$key}->{'fh'};
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
	foreach my $key (keys %{$LOGGERS})
	{
		my $logger = $LOGGERS->{$key};

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
	my ($msg)   = Declassify(\@_, __PACKAGE__);
	my $details = GetDetails();

	$details->{'message'} = $msg;
	$details->{'level'}   = 'FATAL';

	_Log($details);
}
#########################################||#########################################



##################################|     ERROR     |#################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub ERROR
{
	my ($msg)   = Declassify(\@_, __PACKAGE__);
	my $details = GetDetails();

	$details->{'message'} = $msg;
	$details->{'level'}   = 'ERROR';

	_Log($details);
}
#########################################||#########################################



##################################|     WARN     |##################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub WARN
{
	my ($msg)   = Declassify(\@_, __PACKAGE__);
	my $details = GetDetails();

	$details->{'message'} = $msg;
	$details->{'level'}   = 'WARN';

	_Log($details);
}
#########################################||#########################################



##################################|     INFO     |##################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub INFO
{
	my ($msg)   = Declassify(\@_, __PACKAGE__);
	my $details = GetDetails();

	$details->{'message'} = $msg;
	$details->{'level'}   = 'INFO';

	_Log($details);
}
#########################################||#########################################



##################################|     DEBUG     |#################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub DEBUG
{
	my ($msg)   = Declassify(\@_, __PACKAGE__);
	my $details = GetDetails();

	$details->{'message'} = $msg;
	$details->{'level'}   = 'DEBUG';

	_Log($details);
}
#########################################||#########################################



##################################|     TRACE     |#################################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub TRACE
{
	my ($msg)   = Declassify(\@_, __PACKAGE__);
	my $details = GetDetails();

	$details->{'message'} = $msg;
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
		if (($caller[3]) && ($caller[3] =~ /^Metaphor::Logging/i))
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
	my $class  = shift();
	my $params = ((@_) && (ref $_[0] eq 'HASH')) ? shift : {};
	my $logdir = (defined $params->{path}) ? $params->{path} : (defined $LOGDIR) ? $LOGDIR : undef;
	my $error  = "!Log path undefined";

	if ($logdir)
	{
		$error = CreateFolder($logdir);

		unless ($error =~ /^!/)
		{
			$error = undef;

			my $tfile = GetFileName($ENV{SCRIPT_FILENAME});
			$tfile = ($tfile) ? $tfile . ".txt" : "temp.txt";

			$params->{'file'}    = $tfile unless (defined $params->{'file'});
			$params->{'path'}    = join('/', ($logdir, $params->{'file'}));
			$params->{'level'}   = 'ALL' unless (defined $params->{'level'});
			$params->{'level'}   = $LEVELS->{$params->{'level'}} unless ($params->{'level'} =~ /^\d+$/);

			return $params->{'path'} if (exists $LOGGERS->{$params->{'path'}});

			$params->{'path'} = $1 if ($params->{'path'} =~ /^(.+)$/);
			$params->{'fh'} = new FileHandle(">> " . $params->{'path'}) || ($error = "!" . $!);

			unless ($error)
			{
				$LOGGERS->{$params->{'path'}} = $params;
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

	if (($path) && (defined $LOGGERS->{$path}))
	{
		close $LOGGERS->{$path}->{'fh'};
		delete $LOGGERS->{$path};
	}
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Metaphor::Logging - Common logging API

=head1 SYNOPSIS

In L<config.json|https://github.com/scottoffen/common-perl/wiki/Metaphor::Config>:

 {
 	...
 	"logging" :
 	{
 		"dir" : "/path/to/log/dir"
 	}
 }

This entry is encouraged, but optional, as you can always override the path when starting a logger.

In your script:

 use Metaphor::Logging; # Exports FATAL ERROR WARN INFO DEBUG TRACE

 # Turns on console output
 Metaphor::Logging->ConsoleOn();

 # Start some loggers
 my $logger1 = Metaphor::Logging->StartLog({ file => "log1.txt", level => "WARN"});
 my $logger2 = Metaphor::Logging->StartLog({ level => "FATAL"});

 # Logs a warning error message, which will show up in the console
 # (because it is turned on) and in $logger1, but not $logger2
 WARN("This is a warning");

 # Stops the logger
 Metaphor::Logging->StopLog($logger1);

 # Logs a warning error message, which will only up in the console
 WARN("This is another warning");

=head1 DESCRIPTION

Write error logging in your B<modules> without worrying about whether or not logging is even turned on, or where the lines to log should go!

Configure logging only in B<executeable scripts>, turn it on and off as needed, log to whatever level is required.

=head2 Methods

Only public methods are documented.  Use undocumented methods at your own risk.

=head3 Exported Methods

=over 12

=item C<FATAL(MSG)>, C<ERROR(MSG)>, C<WARN(MSG)>, C<INFO(MSG)>, C<DEBUG(MSG)>, C<TRACE(MSG)>

Writes MSG out to all logs that accept that level of logging. If a log is set to accept message at a given level, all messages of a lower level will also be logged. Log levels are, in order:

=over 4

=item * FATAL (1)

=item * ERROR (2)

=item * WARN (3)

=item * INFO (4)

=item * DEBUG (5)

=item * TRACE (6)

=item * ALL (7, Default)

=back

So if your logger is configured to WARN, ERROR and FATAL messages are also logged, but not INFO, DEBUG or TRACE.

All line breaks (CLRFs) will be removed from MSG. The order of fields written to the log:

=over 4

=item * Date/Time

=item * IP Address (if applicable)

=item * Process Id

=item * Script Name

=item * Package Name

=item * Subroutine

=item * Line Number

=item * Logging Level

=item * MSG

=back

=back

=head3 Other Methods

=over 12

=item C<Console(0|1)>, C<ConsoleOn()>, C<ConsoleOff()>

Methods for turning console output on (C<Console(1)> or C<ConsoleOn()>) or off (C<Console(0)> or C<ConsoleOff()>).

When console output is turned on, every message of every level will be sent to <STDOUT> prior to being logged elsewhere.  You do not need to start a log in order to see console output.

=item C<StartLog(HASHREF)>

Configures a logger using the parameters specified in the C<HASHREF>, returns an id for the specified log (so you can turn it off later).

The C<HASHREF> can contain the following values.  Defaults are specified.

=over 4

=item * file  : The filename for the log. Defaults to the name of the running script + ".txt".  Uses "temp.txt" if the name of the running script cannot be determined.

=item * path  : The path to the directory where the log file should be stored. Defaults to the value specified in your config. If the directory doesn't exists, an attempt will be made to create it.

=item * level : Can be I<FATAL>, I<ERROR>, I<WARN>, I<INFO>, I<DEBUG>, I<TRACE> or I<ALL>. Defaults to I<ALL>.

=back

=item C<StopLog(LogId)>

Stops the log specified by LogId.

All logs are closed nicely when script execution is complete, so it is only necessary to do this when you want to turn off a log during execution.

=back

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

=over 1

=item * L<Metaphor::Config|https://github.com/scottoffen/common-perl/wiki/Metaphor::Config>

=item * L<Metaphor::Storage|https://github.com/scottoffen/common-perl/wiki/Metaphor::Storage>

=item * L<Metaphor::Util|https://github.com/scottoffen/common-perl/wiki/Metaphor::Storage>

=back

=cut