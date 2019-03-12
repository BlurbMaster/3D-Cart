#!/usr/bin/perl

#
# Parse the new HTML file with the inventory data from JAL
#
#
# The argument is the name of the HTML file to be read
#

use FileHandle;
use Text::CSV_XS;
use dieHTML;
use strict;
use constant NO_DESCRIPTION => 'Description not available';
use constant { TRUE => 1, FALSE => 0 };

# Declare scopes

# File IO handles
my $input_fh;
my $output_fh;

# Various counters
my $counter = 0;

# The array of column names.  Read in from the first line of the CSV file.
my @output_cols;

# The hash of the fields in the CSV row we have read in 
my %csv_row =( );

# The CSV manipulation object
my $output_csv;

# The constructor for this script
BEGIN{
    my $numargs = @ARGV;
    die "Wrong number of arguments: should be the input file name\n"
      unless( $numargs == 1 );

    my( $inputFile ) =  @ARGV;

    # Set up initial objects

    unless( $input_fh = FileHandle->new ){
	die "Cannot get input file handle: $!";
    }

    unless( $input_fh->open( "< $inputFile" ) ){
	die "Cannot open input file: $!";
    }

    unless( $output_fh = FileHandle->new ){
	die "Cannot get output file handle: $!";
    }

    unless( $output_fh->open( ">/Users/count/Desktop/whatever.csv" ) ){
	die "Cannot open output file: $!";
    }

    $output_csv = Text::CSV_XS->new( { allow_whitespace => 1, eol => "\015\012",
				always_quote => 1, binary => 1, auto_diag => 2
			      });

    @output_cols = ( 'number', 'name', 'company', 'category',
		     'cost', 'sale', 'soldout', 'numSold', 'stock',
		     'specials', 'best', 'new', 'releasedDate', 'blurb' );
}

#
# Scan down the file looking for something. 
# Note that the search is case insensitive.
#
sub Looky{
    my( $fh, $pattern, $line_ptr ) = @_;

    until( ${$line_ptr} =~ m/$pattern/i ){
	last unless ${$line_ptr} = $fh->getline( );
    }
    my $found = (defined ${$line_ptr}) ? 1 : 0;
    return $found;
}
# Clean rubbish out of a string
sub cleanup{
    my $line_ptr = shift @_;

    $$line_ptr =~ s/[^[:ascii:]]+/ /g;  # get rid of non-ASCII characters
    $$line_ptr =~ s/^\s*//;
    $$line_ptr =~ s/\s+/ /g;

    return TRUE;
}

# MAINLINE
# Output the header

$output_csv->combine( @output_cols );
my $latest_row = $output_csv->string();
$latest_row =~ s/(\r|\n)+$//g;
print $output_fh "$latest_row\r\n";

# Skip over original header
die unless &Looky( $input_fh, '\<TR HEIGHT\=26', \$latest_row );

while ( $latest_row = $input_fh->getline( ) ){
    %csv_row = ( );

    last unless &Looky( $input_fh, '\<TR HEIGHT\=26', \$latest_row );

    $latest_row = $input_fh->getline( );

    # Get the standard one-line header items
    for( my $i = 0; $i < 13; $i++ ){
	die unless &Looky( $input_fh, '<td', \$latest_row );
	&dieHTML::noHTML( \$latest_row );
	die "1 - $csv_row{number}\n" unless length $latest_row;
	&cleanup( \$latest_row );
	$latest_row =~ s/\s*$//;
	$csv_row{$output_cols[$i]} = $latest_row;
	$latest_row = $input_fh->getline( );
    }


    # Get the product blurb
    die "2 - $csv_row{number}\n" unless length $latest_row;
    &cleanup( \$latest_row );

    if( &Looky( $input_fh, '<td', \$latest_row ) ){

	# Check for empty table cell
	$latest_row =~ s/^\<td.*?\>//i;  # Get rid of enclosing token start
	$latest_row =~ s/^\s*//;
	$latest_row =~ s/\s*$//;
	
	if( $latest_row !~ m/^\<\/td\>$/i ){

	    #
	    # Ok, now we've got a blurb with something in it -
	    # usually very corrupt HTML
	    #
	    $latest_row =~ s/\r|\n/ /g;
	    my $blurb = $latest_row;

	    while( $latest_row !~ m/^\<\/tr\>\s*$/i ){
		$latest_row = $input_fh->getline( );

		# Many useless empty lines
		unless( (length $latest_row) && ($latest_row =~ m/\S/) ){
		    $latest_row = ' ';
		    next;
		}
		&cleanup( \$latest_row );
		$blurb .= $latest_row;
	    }
	    die "2 - $csv_row{number}\n" unless length $blurb;
	    &cleanup( \$blurb );
	    $blurb =~ s/\r|\n/ /g;
	    
	    # Get rid of trailing enclosing tokens
	    $blurb =~ s/\<\/tr\>\s*$//i;
	    $blurb =~ s/\<\/td\>\s*$//i;

	    #
	    # Turn single and double quote marks into their HTML
	    # representations or CSV will die on them.  This will create a lot
	    # of invalid CSS but none of it was going to work on our site
	    # anyway.  The browsers should just ignore all this and just
	    # use the basic HTML to lay out the blurbs.
	    #
	    $blurb =~ s/\'/&quot\;/g;
	    $blurb =~ s/\"/&#039\;/g;
	    $csv_row{blurb} = $blurb;

	}else{
	    $csv_row{blurb} = NO_DESCRIPTION;
	}

    }else{
	$csv_row{blurb} = NO_DESCRIPTION;
    }

    # Put the hash back into a CSV string
    $output_csv->combine( map { $csv_row{$_} } @output_cols ) or
      die "Failure to create new line for product $counter\n";
    my $latest_row = $output_csv->string();
    print $output_fh $latest_row;
    $counter++;
    
    if( $counter % 1111 == 0 ){
	print STDERR "$counter products processed\n";
    }
} # End of loop reading in HTML records

$input_fh->close;
$output_fh->close;
print STDOUT "Total products: $counter\n";
print STDOUT "Output is in /Users/count/Desktop/whatever.csv\n";

