package VerticalTemplate;
our $VERSION = '1.0.0';

#########################################||#########################################
#                                                                                  #
# VerticalTemplate                                                                 #
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
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# Global Variables                                                                 #
#----------------------------------------------------------------------------------#
	our $TABLE    = '';
	our @FIELDS   = qw(Id Label Value);
	our $FIELDS   = join(', ', map{ "$TABLE.$_" } @FIELDS);

	our $GUID     = '[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}';
	our $BOOL     = '(1|0|true|false)';
	our $NAME     = '.{1,100}';

	our $DEFAULTS =
	{
		'SomeLabel' => 'Default Value',
	};
#----------------------------------------------------------------------------------#


##################################|     new     |###################################
sub new
{
	my $class = shift;
	my $valid = 0;

	#----------------------------------------------------------------------------------#
	# Initialize the object                                                            #
	#----------------------------------------------------------------------------------#
	my $self  =
	{
		#----------------------------------------------------------------------------------#
		# These represent the fields for a given row of data (or variations of them, such  #
		# as raw unix dates vs formatted dates). Provide defaults values as appropriate.   #
		#----------------------------------------------------------------------------------#
		'Id'      => undef,
		'Changes' => {},
		#----------------------------------------------------------------------------------#


		#----------------------------------------------------------------------------------#
		# I find it handy to have a validator available for each field, so it is easy to   #
		# consistently check the value being assigned to a field.                          #
		#----------------------------------------------------------------------------------#
		'Validator'    =>
		{
			'Id' => qr{^$GUID$}i
		}
		#----------------------------------------------------------------------------------#
	};

	@$self{keys %$DEFAULTS} = values %$DEFAULTS;
	%{$self->{'Changes'}}   = map { $_ => 0 } keys %$DEFAULTS;

	delete $self->{'Changes'}->{'Id'};
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Fetch data from the database for a specific element by passing the elements GUID #
	#----------------------------------------------------------------------------------#
	if (IsGuid($_[0]))
	{
		($self->{Id}) = @_;

		foreach (Fetch("select $FIELDS from $TABLE where Id = ?", [$self->{Id}]))
		{
			my @row = @{$_};
			$self->{$row[1]} = $row[2] if ((!exists $self->{Validator}->{$row[1]}) || ($row[2] =~ $self->{Validator}->{$row[1]}));
		}

		$valid = 1;
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
		return undef;
	}
	#----------------------------------------------------------------------------------#
}
#########################################||#########################################



################################|     SomeLabel     |###############################
sub SomeLabel
{
	my ($self, $value) = @_;

	if ((defined $value) && ($value ne $self->{SomeLable}))
	{
		if (!defined $self->{Validator}->{SomeLable}) || ($value =~ $self->{Validator}->{SomeLable})
		{
			$self->{SomeLable} = $value;
			$self->_Save('SomeLable');
		}
	}

	return $self->{SomeLable};
}
#########################################||#########################################



##################################|     Save     |##################################
sub _Save
{
	my ($self, $label) = @_;
	my $result = 0;

	if (($label) && (defined $self->{$label}) && ($label !~ /^(Id|Changes|Validator)$/i))
	{
		if ((defined $DEFAULTS->{$label}) && ($self->{$label} eq $DEFAULTS->{$label}))
		{
			$result = Execute("delete from $TABLE where Id = ? and Label = ?", [ $self->{Id}, $label ]);
		}
		else
		{

			my $result = Execute("update $TABLE set Value = ? where Id = ? and Label = ?", [ $self->{$label}, $self->{Id}, $label ]);

			unless ($result)
			{
				$result = Execute("insert into $TABLE (Id, Label, Value) values (?,?,?)", [ $self->{Id}, $label, $self->{$label} ]);
			}
		}
	}

	return $result;
}
#########################################||#########################################



##################################|     Reset     |##################################
sub Reset
{
	my ($self) = @_;

	Execute("delete from $TABLE where Id = ?", [ $self->{Id} ]);
	@$self{keys %$DEFAULTS} = values %$DEFAULTS;

	return 1;
}
#########################################||#########################################



#################################|     Fields     |#################################
sub Fields
{
	my $fields =
	{
		'SomeLable' =>
		{
			'order' => 0,
			'label' => 'Top Calls Label',
			'type'  => 'text'
		}
	};

	foreach my $key (keys %$DEFAULTS)
	{
		$fields->{$key}->{default} = $DEFAULTS->{$key} if (exists $fields->{$key});
	}
}
#########################################||#########################################



1;

__END__

Include the table definition used by this module here, followed by POD

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