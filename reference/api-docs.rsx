#!C:\lang\perl\bin\perl.exe
#!/usr/bin/perl -T
use strict;
use warnings;
use Fcntl qw(:flock);
use Try::Tiny;
use Cwd;
use JSON::PP;


#########################################||#########################################
#                                                                                  #
# Perl Swagger Resource Listing Generator                                          #
# © Copyright 2014 Robot Scott LCC (http://www.robotscott.com)                     #
#                                                                                  #
# Specification : https://github.com/wordnik/swagger-core/wiki/Resource-Listing    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Script Initialization                                                            #
#----------------------------------------------------------------------------------#
BEGIN
{
	$| = 1;
	unshift(@INC, 'C:/source/github/common-perl');
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# External Dependencies                                                            #
#----------------------------------------------------------------------------------#
	use Common::Config;
	my  $config  = (exists GetConfig()->{'swagger'}) ? GetConfig()->{'swagger'} : { 'api-version' => '1.0.0', 'swagger-version' => '1.2' };
	our $VERSION = $config->{'api-version'};
	our $SWAGGER = $config->{'swagger-version'};
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Initialize resource listing data structure                                       #
#----------------------------------------------------------------------------------#
my $resources =
{
	"apiVersion"     => $VERSION,
	"swaggerVersion" => $SWAGGER,
	"apis"           => []
};

if (defined $config->{info})
{
	$resources->{info} = $config->{info};
}

if (defined $config->{authorizations})
{
	$resources->{authorizations} = $config->{authorizations};
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Retrieve a list of all services files (.rsv) in the current working directory    #
#----------------------------------------------------------------------------------#
my ($servicedir, @files);
{
	$servicedir = cwd();
	opendir(DIR, $servicedir);
	@files = grep { (!/^\./) && (-f "$servicedir/$_") && (/\.rsv$/) } readdir(DIR);
	closedir DIR;
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Add description and path for all services                                        #
#----------------------------------------------------------------------------------#
foreach my $file (sort @files)
{
	local $/;
	open(FILE, "<" . join("/", ($servicedir, $file)));
	flock (FILE, LOCK_SH);
	my $code = <FILE>;
	close(FILE);

	my $description = ($code =~ /=begin description(.+)=end description/s) ? $1 : '';
	$description =~ s/^(\r?\n)+//;
	$description =~ s/(\r?\n)+$//;

	push(@{$resources->{apis}}, { "path" => "/$file", "description" => $description });
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Output the resourse listing                                                      #
#----------------------------------------------------------------------------------#
{
	try
	{
		print "Content-type: application/json\n\n" if (exists $ENV{'HTTP_HOST'});
		print encode_json($resources);
	}
	catch
	{
		print "Content-type: text/html\n\n";
		print "Error creating api-docs : $_";
	};
}
#----------------------------------------------------------------------------------#

exit;