#!/usr/bin/perl
use strict;

my $database = "/home/starman/db/StuffTracker.db";

################################################################################
#
## StuffTracker import script
## v0.01 [2016-02-19]
#
## Use: perl csv_import.pl file.csv
#
################################################################################

###
## Modules to Use
###

use DBI;
use Carp;
use Text::CSV;

###
## Global Variables
###

my $csv_file = $ARGV[0] or die "Need to get CSV file on the command line\n";

my $dbh = &_db_handle($database);
my $sql = {};
my $sth = {};

my $csv = Text::CSV->new({ binary => 1, sep_char => "," });

my %title_hash = ();
my @body_array = ();

###
## Main
###

## Continue if CSV file exists

if(-e $csv_file){ 

    ###########################################################################
    ###
    ## Read and extract CSV data
    ###
    ###########################################################################

    print "\n- Analyzing $csv_file...\n";

    open(my $file_handle, '<:encoding(utf8)', $csv_file) or die "Could not open '$csv_file' $!\n";

    while (my $csv_field_arrayref = $csv->getline( $file_handle )){

        # Match first row
        if($. == 1){

            ## Asume first row contains the column name/title
            
            # Use array index as hash key identifier
            for my $i (0 .. $#$csv_field_arrayref){

                # Create hash reference using array index as hash key
                $title_hash{ $i } = { title => $csv_field_arrayref->[ $i ] };
            }
        }
        else{

            ## Subsecuent rows contain the csv bulk data
            
            my %temporary_hash = ();

            # Use array index as hash key identifier to identify on what column the field belongs to
            for my $i (0 .. $#$csv_field_arrayref){
                $temporary_hash{ $i } = $csv_field_arrayref->[ $i ];
            }

            # Create an array of anonymous hash references with the csv bulk data
            push @body_array, \%temporary_hash;
        }
    }

    ###########################################################################
    ###
    ## Compare extracted CSV column titles to previously defined columns in DB
    ###
    ###########################################################################

    print "- Fetching DB columns and comparing to CSV column titles...\n";

    $sql->{1} = qq(select 
                    a.name as column,
                    a.description as column_description,
                    b.name as column_type
                   from
                    db_column a,
                    db_column_type b
                   where
                    b.db_column_type_id = a.db_column_type_to_db_column_id);

    $sth->{1} = $dbh->prepare($sql->{1}) or carp("Error in sth_1");
    $sth->{1}->execute() or carp("Error in sth_1 execute");
    my $sql_1_result_arrayref = $sth->{1}->fetchall_arrayref({});

    ## Aggregate matched results to %title_hash

    for my $database_hashref (@$sql_1_result_arrayref){

        for my $title_hash_key (keys %title_hash){

            # If CSV title matches with DB
            if($title_hash{ $title_hash_key }{title} eq $database_hashref->{column_description}){
                
                # Append DB column name and type to %title_hash
                $title_hash{ $title_hash_key }{name} = $database_hashref->{column};
                $title_hash{ $title_hash_key }{type} = $database_hashref->{column_type};
            }
        }
    }

    ###########################################################################
    ###
    ## Import results from CSV body, according to CSV column title already matched with existing DB column
    ###
    ###########################################################################
   
    print "- Imporing CSV data to DB...\n";

    ## Iterate through @body_array, which contain anonymous hash references

    foreach my $body_hashref (@body_array){

        ## Create new stuff_tracker table entry for each CSV row

        $sql->{2} = qq(insert into stuff_tracker (created) values ((datetime('now','localtime'))));
        $sth->{2} = $dbh->prepare($sql->{2}) or carp("Error in sth_2");
        $sth->{2}->execute() or carp("Error in sth_2 execute");

        ## Extract the stuff_tracker table entry ID generated on insert 

        my $db_insert_id = $dbh->last_insert_id(undef,undef,"stuff_tracker",undef) || undef;

        print "\n+ Adding row with the following data:\n";

        ## Iterate through %$body_hashref to match the keys with those in %title_hash

        for my $body_hashref_key (sort keys %$body_hashref){

            my $column_name        = $title_hash{ $body_hashref_key }{name} || undef;
            my $column_description = $title_hash{ $body_hashref_key }{title};
            my $column_type        = $title_hash{ $body_hashref_key }{type};
            my $cell_data          = $body_hashref->{ $body_hashref_key };

            ## Only continue if there is a matched database column previously stored in %title_hash

            if(defined($column_name)){

                ## Prepare import according to database column type

                if($column_type eq "varchar"){

                    $sql->{3} = qq(update stuff_tracker set $column_name = ? where stuff_tracker_id = ?);
                    $sth->{3} = $dbh->prepare($sql->{3}) or carp("Error in sth_2");
                    $sth->{3}->execute($cell_data,$db_insert_id) or carp("Error in sth_2 execute");

                    # print results indicating success in updating database
                    print "-- " . $column_description . " -> " . $cell_data . "\n";
                }
                if($column_type eq "integer"){

                    $cell_data =~ s/,//;

                    # Use regular expression to match only integers, due to limitations in DB column definition.
                    
                    if($cell_data =~ /^\d+$/){

                        $sql->{3} = qq(update stuff_tracker set $column_name = ? where stuff_tracker_id = ?);
                        $sth->{3} = $dbh->prepare($sql->{3}) or carp("Error in sth_2");
                        $sth->{3}->execute($cell_data,$db_insert_id) or carp("Error in sth_2 execute");

                        # print results indicating success in updating database
                        print "-- " . $column_description . " -> " . $cell_data . "\n";
                    }
                }
                if($column_type eq "date"){

                    # Use regular expression to help convert input date to database date.
                   
                    if($cell_data =~ /^(\d+)\-(\w+)\-(\d+)$/){

                        my $day   = $1;
                        my $month = $2;
                        my $year  = $3;

                        my $converted_month = &_month_name_to_month_number($month);
                        my $converted_day   = &_add_zero($day);

                        my $db_safe_date = $year . '-' . $converted_month . '-' . $converted_day;

                        $sql->{3} = qq(update stuff_tracker set $column_name = ? where stuff_tracker_id = ?);
                        $sth->{3} = $dbh->prepare($sql->{3}) or carp("Error in sth_2");
                        $sth->{3}->execute($db_safe_date,$db_insert_id) or carp("Error in sth_2 execute");

                        # print results indicating success in updating database
                        print "-- " . $column_description . " -> " . $cell_data . "\n";
                    }
                }
                if($column_type eq "select"){

                    # The select column type depends on database foreign tables.
                    
                    # Search for foreign table id using CSV field input

                    my $foreign_table    = $column_name;
                    my $foreign_table_id = $foreign_table . "_id";

                    $sql->{3} = qq(select $foreign_table_id as id from $foreign_table where description = ?); 
                    $sth->{3} = $dbh->prepare($sql->{3}) or carp("Error in sth_3");
                    $sth->{3}->execute($cell_data) or carp("Error in sth_3 execute");
                    my $sql_3_result_hashref = $sth->{3}->fetchrow_hashref;
                    $sth->{3}->finish;
                    
                    my $match = $sql_3_result_hashref->{id} || undef;

                    if(defined($match)){

                        my $foreign_table_relation = $foreign_table . "_to_stuff_tracker_id";

                        $sql->{4} = qq(update stuff_tracker set $foreign_table_relation = ? where stuff_tracker_id = ?);
                        $sth->{4} = $dbh->prepare($sql->{4}) or carp("Error in sth_4");
                        $sth->{4}->execute($match,$db_insert_id) or carp("Error in sth_4 execute");
                        print "-- " . $column_description . " -> " . $cell_data . "\n";
                    }
                }
            }
        }
        print "\n";
    }
}

$dbh->disconnect;

###
## Subs
###

sub _db_handle {

    my ($database) = @_;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$database","","", {RaiseError => 1}) or croak("Could not connect to DB: $DBI::errstr");
    $dbh->{sqlite_unicode} = 1;

    return $dbh;
}

sub _month_name_to_month_number {

    my ($month_name) = @_;

    my %month_hash = ( 
        'Jan' => '01',
        'Feb' => '02',
        'Mar' => '03',
        'Apr' => '04',
        'May' => '05',
        'Jun' => '06',
        'Jul' => '07',
        'Aug' => '08',
        'Sep' => '09',
        'Oct' => '10',
        'Nov' => '11',
        'Dec' => '12',
    );
    return $month_hash{ $month_name };
}

sub _add_zero {

    my ($number) = @_;

    if($number =~ /^\d$/){ 
        $number = "0$number"; 
    }    
    return $number;
}
