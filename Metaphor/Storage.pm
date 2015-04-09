package Metaphor::Storage;

#########################################||#########################################
#                                                                                  #
# Metaphor::Storage                                                                #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use English qw(-no_match_vars);
	use MIME::Base64;
	use Fcntl qw(:DEFAULT :flock);
	use Metaphor::Util qw(Declassify);
	use base 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables and Exports                                                     #
#----------------------------------------------------------------------------------#
	our $VERSION     = '1.0.0';
	our @EXPORT      = qw(CreateFolder DeleteFolder DownloadFile GetFileName GetFilePath GetListing GetFileAsBase64);
	our @EXPORT_OK   = @EXPORT;
	our %EXPORT_TAGS =
	(
		'all'     => [qw(CreateFolder DeleteFolder DownloadFile GetFileName GetFilePath GetListing GetFileAsBase64)],
		'files'   => [qw(GetFileName GetFilePath)],
		'folders' => [qw(CreateFolder DeleteFolder GetListing)],
		'web'     => [qw(DownloadFile GetFileAsBase64)]
	);

	our $EMPTY          = q{};
	our $PATH_SEPARATOR = q{/};
#----------------------------------------------------------------------------------#


#############################|     Create Folder     |##############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub CreateFolder
{
	my ($folder) = Declassify(\@_, __PACKAGE__);
	my (@path, $path, $pass);

	#----------------------------------------------------------------------------------#
	# Immediate returns if there is no folder or if the folder already exists.         #
	#----------------------------------------------------------------------------------#
	return unless ($folder);
	return $folder if (-d $folder);
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Clean up the folder path and put it into an array                                #
	#----------------------------------------------------------------------------------#
	$folder =~ s/\\{1,}/\//g;
	@path   = split(/\//, $folder);

	shift (@path) unless ($path[0]);  #--> Remove any leading whitespace
	pop   (@path) unless ($path[-1]); #--> Remove any trailing whitespace
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Create the return value.  On Win32 machines, it is assumed that the first value  #
	# in the array created in the previous step is a drive letter, and therefore pre-  #
	# populates this in the return value and removes the first element from the array. #
	#----------------------------------------------------------------------------------#
	$path = ($OSNAME =~ /^MSWin.+/i) ? shift(@path) : $EMPTY;
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Create the folder                                                                #
	#----------------------------------------------------------------------------------#
	foreach my $folder (@path)
	{
		next unless ($folder);

		$path = join($PATH_SEPARATOR, ($path, $folder));
		$path = $1 if ($path =~ /^(.+)$/);

		unless (-d $path)
		{
			$pass = mkdir($path, 0777);
			return $pass unless ($pass);
		}
	}
	#----------------------------------------------------------------------------------#

	return $path;
}
#########################################||#########################################



#############################|     Delete Folder     |##############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub DeleteFolder
{
	my @params = Declassify(\@_, __PACKAGE__);
	my $folder = ($params[0] =~ /^(.+)$/) ? $1 : undef;

	#----------------------------------------------------------------------------------#
	# Immediate returns if there is no folder or if the folder does not exists.        #
	#----------------------------------------------------------------------------------#
	return unless (($folder) && (-e $folder) && (-d $folder));
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Read the folder contents                                                         #
	#----------------------------------------------------------------------------------#
	opendir(DIR, "$folder");
	my @contents = readdir(DIR);
	closedir(DIR);
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Delete contents of folder                                                        #
	#----------------------------------------------------------------------------------#
	foreach my $file (@contents)
	{
		next if ($file =~ /^\.{1,2}$/);
		$file = $1 if ($file =~ /^(.+)$/);

		if (-d "$folder/$file")
		{
			DeleteFolder("$folder/$file");
		}
		else
		{
			unlink("$folder/$file");
		}
	}
	#----------------------------------------------------------------------------------#

	return rmdir("$folder");
}
#########################################||#########################################



##############################|     DownloadFile     |##############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub DownloadFile
{
	my ($path, $file) = Declassify(\@_, __PACKAGE__);
	$file = GetFileName($path) unless (defined $file);

	if (-e $path)
	{
		print "Content-Type:application/octet-stream\n";
		print "Content-Disposition:attachment;filename=$file\n\n";

		my $opened = open my $fh, '<', $path;
		if ($opened)
		{
			flock($fh, LOCK_SH);
			binmode($fh);
			print <$fh>;
			my $closed = close $fh;
		}
	}
	else
	{
		print "Content-type: text/html\n\n";
		print "File $path not found.\n";
	}

	return 1;
}
#########################################||#########################################



#############################|     GetFileAsBase64     |############################
# Export OK                                                                        #
#----------------------------------------------------------------------------------#
sub GetFileAsBase64
{
	my ($file) = Declassify(\@_, __PACKAGE__);
	my $data;

	if ((-e $file) && (!(-d $file)))
	{
		my $d;

		my $opened = open my $fh, '<', $file;
		if ($opened)
		{
			flock($fh, LOCK_SH);
			binmode($fh) unless (-T $file);
			local $INPUT_RECORD_SEPARATOR = undef;
			$d = <$fh>;
			my $error = close $fh;
		}

		$data = encode_base64($d);
	}

	return $data;
}
#########################################||#########################################



###############################|     GetFileName     |##############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub GetFileName
{
	my ($path) = Declassify(\@_, __PACKAGE__);
	my $file = undef;
	my @path;

	if (($path) && (length $path > 0))
	{
		$path =~ s/\\{1,}/\//g;
		@path = split(/\//, $path);

		$file = $path[-1];
	}

	return $file;
}
#########################################||#########################################



###############################|     GetFilePath     |##############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub GetFilePath
{
	my ($path) = Declassify(\@_, __PACKAGE__);
	my @path;

	if (($path) && (length $path > 0))
	{
		$path =~ s/\\{1,}/\//g;
		@path = split(/\//, $path);
		pop(@path);
		$path = join($PATH_SEPARATOR, @path);
	}

	return $path;
}
#########################################||#########################################



###############################|     GetListing     |###############################
# Exported                                                                         #
#----------------------------------------------------------------------------------#
sub GetListing
{
	my @params    = Declassify(\@_, __PACKAGE__);
	my $directory = CreateFolder($params[0]);
	my $listing   = [];

	opendir(DIR, "$directory");
	while (my $item = readdir(DIR))
	{
		next if (-d join($PATH_SEPARATOR, ($directory, $item)));
		next if ($item =~ /^thumbs\.db$/i);

		push(@{$listing}, $item);
	}
	closedir(DIR);

	return (wantarray) ? @{$listing} : $listing;
}
#########################################||#########################################



1;

__END__

=pod

=head1 NAME

Metaphor::Storage - Common Storage API

=head1 SYNOPSIS

 # Exports CreateFolder DeleteFolder DownloadFile GetFileName GetListing
 use Metaphor::Storage;

 # Additionally exports GetFileAsBase64
 use Metaphor::Storage (':all');

 # Exports just GetFileAsBase64
 use Metaphor::Storage ('GetFileAsBase64');

 my $folder = "/some/folder/path";
 my $file   = join("/", ($folder, "file.pdf"));

 # Create a folder at the path specified
 my $folder = CreateFolder($folder);
 unless ($folder)
 {
	print "Error creating folder : $!";
 }

 # Get the name of a specific file
 my $filename = GetFileName($file);
 print "$filename";
 > file.pdf

 # Get a directory listing as array or arrayref
 my @listing = GetListing($folder);
 my $listing = GetListing($folder);

 # Get a file as Base64
 my $base64file = GetFileAsBase64($file);

 # Download a file to a browser
 DownloadFile($file, "myfile.pdf");

 # Delete the folder and everything in it
 unless (DeleteFolder($folder))
 {
	print "Error deleting folder : $!";
 }

=head1 DESCRIPTION

A utility library for managing stored items.  Includes:

=over 4

=item * Creating and Deleting folders and folders structures

=item * Sending files to a browser for download (not rendering)

=item * Getting a directory listing or a file name based on a path

=item * Base64 encoding a file from a string path

=back

=head2 Methods

Only public methods are documented.  Use undocumented methods at your own risk.

=head3 Exported Methods

=over 12

=item C<CreateFolder(PATH)>

If the folder specified by PATH exists, it returns PATH.  If the folder does not exist, it attempts to create (using mask 0777) the folder - and all parent folders as needed - and returns either the path it was able to create on success or false (0, and sets $! (errno)) on failure.

 my $folder = CreateFolder($folder);
 unless ($folder)
 {
	print "Error creating folder : $!";
 }

Be aware, however, that a folders existence does not automatically mean that you can read/write to that folder.

=item C<DeleteFolder(PATH)>

Attempts to delete the folder specified by PATH and all files and folders underneath it. Returns true (1) on success and false (0, and sets $! (errno)) on failure.

 unless (DeleteFolder($folder))
 {
	print "Error deleting folder : $!";
 }

=item C<DownloadFile(PATH, FILENAME)>

 # Download a file to a browser
 DownloadFile($file, "myfile.pdf");

If a file (not a directory) exists at PATH, prints to <STDOUT>:

 Content-Type:application/octet-stream
 Content-Disposition:attachment;filename=myfile.pdf

 [contents of file.pdf]

If no file exists at PATH, prints to <STDOUT>:

 Content-type: text/html

 File $file not found.

This is a very simple way to download a file as an attachment in response to the execution of a script, and give it any filename you want.

=item C<GetFileName(PATH)>

Returns the part of the path that follows the last path separation character.  It will auto convert C<\\> to C</> in order to do this, but still works on both *NIX and Windows platforms.  If the PATH isn't a file, it returns the last folder specified.

 # Get the name of a specific file
 my $filename = GetFileName($file);
 print "$filename";
 > file.pdf

=item C<GetListing(PATH)>

Returns an array or arrayref of all files in the directory specified by PATH.  It omits any directories, as well as the C<thumbs.db> file.

 # Get a directory listing as array or arrayref
 my @listing = GetListing($folder);
 my $listing = GetListing($folder);

=back

=head3 Export OK Methods

=over 12

=item C<GetFileAsBase64(PATH)>

Opens the file located at PATH and returns the Base64 encoded version of it.  Returns C<undef> if there is no file at PATH or if PATH is a directory.

 # Get a file as Base64
 my $base64file = GetFileAsBase64("/path/to/file.pdf");

=back

=head1 TODO

I might consider rewriting C<CreateFolder> and C<DeleteFolder> using C<L<File::Path|http://perldoc.perl.org/File/Path.html>> someday in the distant future, but this method has been working perfectly since long before that module was available to me, so I'm in no hurry to do so.

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

=over 1

=item * L<Metaphor::Util|http://https://github.com/scottoffen/common-perl/wiki/Metaphor::Util>

=item * L<MIME::Base64|http://search.cpan.org/~gaas/MIME-Base64-3.14/Base64.pm>

=item * L<Fcntl|http://search.cpan.org/~rjbs/perl-5.18.2/ext/Fcntl/Fcntl.pm>

=back

=cut