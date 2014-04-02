



	if ((keys %{$self->{Files}}) > 0)
	{
		$boundary = $self->_CreateBoundaryString();
		push (@header, 'Content-type: multipart/mixed; boundary="' . $boundary . '"');
		$type = 'MIXED';
	}

	elsif ((defined $self->{Text}) && (defined $self->{Html}))
	{
		$boundary = $self->_CreateBoundaryString();
		push (@header, 'Content-type: multipart/alternative; boundary="' . $boundary . '"');
		$type = "ALT";
	}

	else
	{
		if (defined $self->{Html})
		{
			push (@header, "Content-type: text/html");
		}
		else
		{
			push (@header, "Content-type: text/plain");
		}
	}

	my $header = join("\n", @header);
	$email = "$header\n\n";

	if (defined $boundary)
	{
		$email .= "This is a message with multiple parts in MIME format.";
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Create the text and html parts                                                   #
	#----------------------------------------------------------------------------------#
	my $retainer = undef;

	if ((defined $type) && ($type eq 'MIXED'))
	{
		$email .= "\n--$boundary\n";

		$retainer = $boundary;
		$boundary = $self->_CreateBoundaryString();

		$email .= "Content-type: multipart/alternative\; boundary=\"" . $boundary . "\"\n\n";
	}

	if (defined $self->{Html})
	{
		if (defined $boundary)
		{
			$email .= "\n--$boundary\n";
			$email .= "Content-Type: text/html\n\n";
		}

		$email .= $self->{Html};
	}

	if (defined $self->{Text})
	{
		if (defined $boundary)
		{
			$email .= "\n--$boundary\n";
			$email .= "Content-Type: text/plain\n\n";
		}

		$email .= $self->{Text};
	}

	if ((defined $type) && ($type eq 'MIXED'))
	{
		$email .= "\n--$boundary--\n";
		$boundary = $retainer;
	}
	#----------------------------------------------------------------------------------#


	#----------------------------------------------------------------------------------#
	# Add attachments                                                                  #
	#----------------------------------------------------------------------------------#
	if ((keys %{$self->{Files}}) > 0)
	{
		#-->TODO: Inline Attachments

		foreach my $key (keys %{$self->{Files}})
		{
			$email .= "\n--$boundary\n";
			$email .= "Content-Type: application/octet-stream\n";
			$email .= "Content-Disposition: " . $self->{Files}->{$key}->{Disposition} . "; filename=" . $self->{Files}->{$key}->{Filename} . "; modification-date=\"" . $self->{Files}->{$key}->{Date} . "\";\n";
			$email .= "Content-ID: <" . $self->{Files}->{$key}->{ContentId} . ">\n";
			$email .= "Content-Transfer-Encoding: base64\n\n";
			$email .= $self->{Files}->{$key}->{Content};
		}
	}

	if (defined $boundary)
	{
		$email .= "\n--$boundary--\n\n";
	}
	#----------------------------------------------------------------------------------#

	return $email;
}
#########################################||#########################################