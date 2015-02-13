package Metaphor::Encryption;
our $VERSION = '1.0.0';

#########################################||#########################################
#                                                                                  #
# Metaphor::Encryption                                                             #
# © Copyright 2011-2014 Scott Offen (http://www.scottoffen.com)                    #
#                                                                                  #
#########################################||#########################################


#----------------------------------------------------------------------------------#
# Pragmas and modules to use                                                       #
#----------------------------------------------------------------------------------#
	use strict;
	use warnings;
	use Metaphor::Util qw(Declassify);
	use Crypt::Eksblowfish::Bcrypt qw(bcrypt en_base64);
	use parent 'Exporter';
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
<<<<<<< HEAD
	our @EXPORT = qw(Encrypt Matches);
=======
	our @EXPORT    = qw(Encrypt Matches);
	our @EXPORT_OK = @EXPORT;
>>>>>>> 36eb25bef48fb85ad9b74d5e77e127ca536f284a

	our %EXPORT_TAGS =
	(
		'all' => [qw(Encrypt Matches)]
	);
#----------------------------------------------------------------------------------#


################################|     Matches     |#################################
# Exportable, Public Static                                                        #
#----------------------------------------------------------------------------------#
sub Matches
{
	my ($value, $salt, $encrypted) = Declassify(\@_, __PACKAGE__);
	return (bcrypt($value, "\$2a\$08\$$salt") eq $encrypted) ? 1 : 0;
}
#########################################||#########################################



################################|     Encrypt     |#################################
# Exportable, Public Static                                                        #
#----------------------------------------------------------------------------------#
sub Encrypt
{
	my ($value) = Declassify(\@_, __PACKAGE__);

	if (defined $value)
	{
		my $salt = GenSalt();
		my $hash = bcrypt($value, "\$2a\$08\$$salt");

		return (length $hash > 13) ? ($hash, $salt) : ();
	}

	return ();
}
#########################################||#########################################



#################################|     GenSalt     |################################
# Private                                                                          #
#----------------------------------------------------------------------------------#
sub GenSalt
{
	my $salt = '';
	for my $i (0..15)
	{
	    $salt .= chr(rand(256));
	}

	return en_base64($salt);
}
#########################################||#########################################


1;

__END__

=pod

=head1 NAME

Metaphor::Encryption - Both a convenience wrapper for L<bcrypt|http://en.wikipedia.org/wiki/Bcrypt>, as well as a way to insulate the rest of the L<Metaphor::Perl|https://github.com/scottoffen/common-perl> framework should I decide to use a different encryption method in the future.

=head1 SYNOPSIS

 # You can export nothing, or export methods individually, or get them all
 use Metaphor::Encryption qw(:all);

 my $password = "password";
 my ($hash1, $salt1) = Encrypt($password);
 my ($hash2, $salt2) = Encrypt($password);

 # First Match
 my $match1 = ((Matches($password, $salt1, $hash1)) ? "pass" : "fail";

 # Second Match
 my $match2 = (Matches($password, $salt2, $hash2)) ? "pass" : "fail";

 # Third Match
 my $match3 = (Matches($password, $salt1, $hash2)) ? "pass" : "fail";

 # Fourth Match
 my $match4 = (Matches($password, $salt2, $hash1)) ? "pass" : "fail";

 print "1 : $match1\n"; # pass
 print "2 : $match2\n"; # pass
 print "3 : $match3\n"; # fail
 print "4 : $match4\n"; # fail

=head1 DESCRIPTION

Use C<Encrypt()> to encrypt a value using bcrypt, and it returns the encrypted value and the salt used to do the encryption.  Store those values somewhere, and then later you can test if an unencrypted value matches the encrypted value using C<Matches()>.

=head2 Methods

Only public methods are documented.

=over 12

=item C<Encrypt(VALUE)>

Pass it the value you want encrypted, and it returns the encrypted value and the salt used in the encryption.

=item C<MATCHES(VALUE, SALT, ENCRYPTED_VALUE)>

Pass it an unencrypted value, the salt to use in the encryption, and the encrypted value to match it against, and it returns true (1) if they match or false (0) if they don't.

=back

=head1 AUTHOR

(c) Copyright 2011-2014 Scott Offen (L<http://www.scottoffen.com/>)

=head1 DEPENDENCIES

=over 1

=item * L<Metaphor::Util|https://github.com/scottoffen/Common-Perl/wiki/Metaphor::Util>

=item * L<Crypt::Eksblowfish::Bcrypt|https://http://search.cpan.org/~zefram/Crypt-Eksblowfish-0.009/lib/Crypt/Eksblowfish/Bcrypt.pm>

=back

=cut