package StuffTracker;
use Dancer2;

our $VERSION = '0.3';

###
## Modules
###

use DBI;
use Digest::MD5 qw(md5_hex);
require JSON::XS;

###
## Database Variables
###

my $db_hash = {
    db         => config->{"db"},
    username   => config->{"db_username"},
    password   => config->{"db_password"},
    host       => config->{"db_host"},
    port       => config->{"db_port"},
    dbi_to_use => config->{"dbi_to_use"} 
};

my $db_auth_hash = {
    db         => config->{"db_auth"},
    username   => config->{"db_auth_username"},
    password   => config->{"db_auth_password"},
    host       => config->{"db_auth_host"},
    port       => config->{"db_auth_port"},
    dbi_to_use => config->{"dbi_to_use"} 
};

###############################################################################
## Main
###############################################################################

get '/' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $header_hash = request->headers;
    my $static_uri  = '';
    my $main_uri    = '';
    if($header_hash->{'x-forwarded-for'}){
        $static_uri = "/".config->{"appname"}."_static/";
        $main_uri   = '/'.config->{"appname"};
    }
    template 'index',{ static_uri    => $static_uri, 
                       main_uri      => $main_uri, 
                       session_user  => session->read('username'),
                       session_admin => session->read('session_admin') };
};

get '/stuff_tracker/:rid?' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $header_hash = request->headers;
    my $hashref     = params;
    my $output      = params->{output} || undef;

    my $result = &stuff_tracker({ content_range => $header_hash->{'x-range'}, params => $hashref });

    if($output){
        header('Content-Type' => 'text/csv','Content-Disposition' => 'attachment; filename="arc.csv"');
        my $scal = join("", @{$result->{csv_output}});
        return $scal;
    }
    else{
        if(not defined(params->{rid})){
            header('Content-Range' => "$result->{content_range}/$result->{result_count}");
        }
        return $result->{json_output};
    }
};

put '/stuff_tracker/:id' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $body    = request->body;
    my $hashref = from_json($body);

    # User
    $hashref->{updated_by} = session('uid');

    &modify_stuff($hashref);
};

post '/add' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $hashref = params;

    # User
    $hashref->{integrated_by} = session('uid');
    $hashref->{updated_by}    = session('uid');

    my $result  = &add_stuff($hashref);
    return $result;
};

post '/delete' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $hashref = params;

    # User
    $hashref->{updated_by} = session('uid');

    my $result  = &delete_stuff($hashref);
    return $result;
};

get '/fetch_columns' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $result = &stuff_tracker_columns();
    return $result->{json_output};
};

## Admin ######################################################################

get '/admin_grid/:column_id' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $header_hash = request->headers;
    my $column_id   = params->{column_id};

    my $result = &admin_grid({ content_range => $header_hash->{'x-range'}, column_id => $column_id });
    header('Content-Range' => "$result->{content_range}/$result->{result_count}");
    return $result->{json_output};
};

put '/admin_grid/:column_id?/:second?' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $body    = request->body;
    my $hashref = from_json($body);
    $hashref->{column_id} = params->{column_id};
    &modify_admin($hashref);
};

post '/admin_add' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $hashref = params;
    my $result  = &admin_add($hashref);
    return $result;
};

## Column Admin ################################################################

get '/column_grid/:rid?' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $header_hash = request->headers;
    my $result = &column_grid({ content_range => $header_hash->{'x-range'} });
    header('Content-Range' => "$result->{content_range}/$result->{result_count}");
    return $result->{json_output};
};

put '/column_grid/:rid?' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $body    = request->body;
    my $hashref = from_json($body);
    $hashref->{action} = "edit";
    &column_admin($hashref);
};

post '/add_column' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $hashref = params;
    $hashref->{action} = "add";
    my $result  = &column_admin($hashref);
    return $result;
};

post '/edit_column' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $hashref = params;
    $hashref->{action} = "edit";
    my $result  = &column_admin($hashref);
    return $result;
};

## Selects ####################################################################

get '/filtering_select/:input/:rid?' => sub {

    ## Check Session
    if(!session('logged_in')){ redirect '/login'; }

    my $input = param 'input';
    my $name  = params->{'name'} || undef;

    if($name){
        my $output = &filtering_select({ input => $input, name => $name });
        return $output->{json_output};
    }
    else{
        return "[]";
    }
};

## Login ######################################################################

any ['get', 'post'] => '/login' => sub {

    my $header_hash = request->headers;
    my $static_uri  = '';
    my $main_uri    = '';
    if($header_hash->{'x-forwarded-for'}){
        $static_uri = "/".config->{"appname"}."_static/";
        $main_uri   = '/'.config->{"appname"};
    }

    my $err = params->{'error_code'};

    if(request->method() eq "POST"){

        my $username = params->{'username'} || undef;
        my $password = params->{'password'} || undef;
        my $output   = {};

        if($username){
            if($password){
               $output = &_db_authen_process_login({username => $username, password => $password});
            }
            else{
                $err = "Invalid password";
            }
        }
        else{
            $err = "Invalid username";
        }

        my $output_not_empty = undef;
        $output_not_empty    = (keys %$output)[-1];
        
        if($output_not_empty){
            if($output->{session_authorized} == 1){
                # Admin
                if( ($output->{privilege} == 1) || ($output->{privilege} == 3) ){
                    session->write('session_admin',1);
                }
                session->write('logged_in',          true);
                session->write('username',           $output->{username});
                session->write('uid',                $output->{uid});
                session->write('full_name',          $output->{full_name});
                session->write('session_authorized', $output->{session_authorized});
                return redirect '/';
            }
            else{
                debug("not authorized");
                $err = $output->{login_message};
            }
        }
    }
    template 'login', { 'err' => $err, static_uri => $static_uri, main_uri => $main_uri };
};

get '/logout' => sub {
    app->destroy_session;
    return redirect '/';
};

any ['get', 'post'] => '/change_password' => sub {

    my $header_hash = request->headers;
    my $static_uri  = '';
    my $main_uri    = '';
    if($header_hash->{'x-forwarded-for'}){
        $static_uri = "/".config->{"appname"}."_static/";
        $main_uri   = '/'.config->{"appname"};
    }

    my $err = params->{'error_code'};

    if(request->method() eq "POST"){
        
        my $param_hash = {};

        $param_hash->{username}      = params->{'username'};
        $param_hash->{password}      = params->{'password'};
        $param_hash->{npassword}     = params->{'npassword'};
        $param_hash->{cpassword}     = params->{'cpassword'};

        my $output = undef;

        if($param_hash->{username}){
            if($param_hash->{password}){
                if($param_hash->{npassword}){
                    if($param_hash->{cpassword}){
                        if($param_hash->{npassword} eq $param_hash->{cpassword}){
                            $output = &_db_change_password($param_hash);
                        }
                        else{
                            $err = "Error - New Password and Confirm New password does not match";
                        }
                    }
                    else{
                        $err = "Error - Confirm New password not entered";
                    }
                }
                else{
                    $err = "Error - New password not entered";
                }
            }
            else{
                $err = "Error - password not entered";
            }
        }
        else{
            $err = "Error - username not entered";
        }

        if($output){
            $err = $output;
        } 
    }
    template 'change_password', { 'err' => $err, static_uri => $static_uri, main_uri => $main_uri };
};

###############################################################################
## Subs
###############################################################################

sub stuff_tracker {
    
    my ($sub_hash) = @_;
    
    my $content_range = $sub_hash->{content_range} || undef;
    my $params        = $sub_hash->{params};

    my $rid    = $params->{rid}    || undef;
    my $query  = $params->{query}  || undef;
    my $output = $params->{output} || undef;

    delete $params->{rid};
    delete $params->{query};
    delete $params->{output};

    my $dbh = &_db_handle($db_hash);
    my $sql = {};
    my $sth = {};

    ## Paging
    my $limit        = "100";
    my $offset       = "0";
    my $result_count = "";

    if( (defined($content_range)) && ($content_range =~ /items\=(\d+)\-(\d+)/) ){
        my $start  = $1;
        my $end    = $2;
        $offset    = $start;
        $content_range = "items " . $start . "-" . $end;
    }

    ## Fetch columns
    
    $sql->{1}     = "select stuff_tracker.stuff_tracker_id as id ";
    $sql->{count} = "select count(stuff_tracker.stuff_tracker_id) ";

    my @main_table_array    = ();
    my @foreign_table_array = ();
    my @search_query_array  = ();
    my %date_column         = (); ## for Filter
    my @csv_column_array    = ();
    my @csv_title_array     = ();

    $sql->{2} = qq(select 
                    a.name as column,
                    a.description as column_description,
                    b.name as column_type
                   from
                    db_column a,
                    db_column_type b
                   where
                    b.db_column_type_id = a.db_column_type_to_db_column_id
                    and a.status_to_db_column_id = ?);

    $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
    $sth->{2}->execute(1) or error("Error in sth_2 execute");
    my $sql_2_result = $sth->{2}->fetchall_arrayref({});

    for my $row (@$sql_2_result){

        if( ($row->{column_type} eq "varchar") || ($row->{column_type} eq "integer") ){
            push @main_table_array,   "stuff_tracker." . $row->{column};
            push @search_query_array, "stuff_tracker." . $row->{column};
        }
        if($row->{column_type} eq "date"){

            if(config->{"dbi_to_use"} eq "SQLite"){
                push @main_table_array,   "stuff_tracker." . $row->{column};
            }
            else{
                push @main_table_array, "to_char(stuff_tracker." . $row->{column} . ",'YYYY-MM-DD') as " . $row->{column};
            }

            $date_column{ $row->{column} }          = $row->{column};
            $date_column{ $row->{column} . "_end" } = $row->{column};
        }
        if($row->{column_type} eq "select"){
            push @main_table_array,    "stuff_tracker." . $row->{column} . "_to_stuff_tracker_id as " . $row->{column} . "_id";
            push @main_table_array,    $row->{column} . ".description as " . $row->{column};
            push @foreign_table_array, $row->{column};
            push @search_query_array,  $row->{column} . ".description";
        }
        ## For CSV Export
        if($output){
            push @csv_column_array, $row->{column};
            push @csv_title_array, $row->{column_description};
        }
    }

    if($main_table_array[0]){
        if($main_table_array[1]){
            $sql->{1} .=  ", ";
            my $last_one = pop @main_table_array;
            for my $row (@main_table_array){
                $sql->{1} .=  " $row, ";
            }
            $sql->{1} .=  " $last_one ";
        }
        else{
            $sql->{1} .=  ", $main_table_array[0] ";
        }
    }

    $sql->{1}     .=  " from ";
    $sql->{count} .=  " from ";

    if($foreign_table_array[0]){
		if($foreign_table_array[1]){
			$sql->{1}     .=  " stuff_tracker, ";
			$sql->{count} .=  " stuff_tracker, ";
			my @temp_array = @foreign_table_array;
			my $last_one   = pop @temp_array;
			for my $row (@temp_array){
				$sql->{1}     .=  " $row, ";
				$sql->{count} .=  " $row, ";
			}
			$sql->{1}     .=  " $last_one ";
			$sql->{count} .=  " $last_one ";
		}
		else{
			$sql->{1}     .=  " stuff_tracker, $foreign_table_array[0] ";
			$sql->{count} .=  " stuff_tracker, $foreign_table_array[0] ";
		}
    }
    else{
        $sql->{1}     .=  " stuff_tracker ";
        $sql->{count} .=  " stuff_tracker ";
    }

    if($foreign_table_array[0]){

        $sql->{1}     .=  " where ";
        $sql->{count} .=  " where ";

		if($foreign_table_array[1]){

			my @temp_array = @foreign_table_array;
			my $last_one   = pop @temp_array;

			$sql->{1}     .=  " " . $last_one . "." . $last_one . "_id = stuff_tracker." . $last_one . "_to_stuff_tracker_id ";
			$sql->{count} .=  " " . $last_one . "." . $last_one . "_id = stuff_tracker." . $last_one . "_to_stuff_tracker_id ";

			for my $row (@temp_array){
				$sql->{1}     .=  " and " . $row . "." . $row . "_id = stuff_tracker." . $row . "_to_stuff_tracker_id ";
				$sql->{count} .=  " and " . $row . "." . $row . "_id = stuff_tracker." . $row . "_to_stuff_tracker_id ";
			}
		}
		else{
			$sql->{1}     .=  " " . $foreign_table_array[0] . "." . $foreign_table_array[0] . "_id = stuff_tracker." . $foreign_table_array[0] . "_to_stuff_tracker_id ";
			$sql->{count} .=  " " . $foreign_table_array[0] . "." . $foreign_table_array[0] . "_id = stuff_tracker." . $foreign_table_array[0] . "_to_stuff_tracker_id ";
		}
    }

    ## Search
    if($query){
            
        $query =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
            
        my $where_query = undef;
            
        if($query =~ /[\w\s\_\-]+/){
                
            $query = uc $query;

            if($search_query_array[0]){

                my @like_array = ();
                my $scalar     = undef;

                for my $row (@search_query_array){
                    push @like_array, " upper(" . $row . ") like '%" . $query . "%' "; 
                }

                if($like_array[1]){
                    $scalar = join(" or ", @like_array);
                }
                else{
                    $scalar = $like_array[1];
                }

                $where_query = qq{ and ($scalar) };
            }
        }
            
        if($where_query){
            $sql->{1}     .= $where_query;
            $sql->{count} .= $where_query;
        }
    }

    ## Filter/Sort
    my $sort_by          = undef;
    my $sort_order       = "asc";
    my $date_hash        = {};
    my $params_not_empty = undef;
    $params_not_empty    = (keys %$params)[-1];
    
    if($params_not_empty){
        for(keys %$params){
            if($_ =~ /^(\w+)\_id$/){
                my $column = $1 . "_to_stuff_tracker_id";
                $sql->{1}     .= qq( and stuff_tracker.$column = $params->{$_} );
                $sql->{count} .= qq( and stuff_tracker.$column = $params->{$_} );
            }
            else{
                ## for Sort
                if($_ =~ /sort\((\-|\s+)(\w+)\)/){
                    $sort_by    = $2;
                    $sort_order = $1;
                    if($sort_order eq "-"){
                        $sort_order = "desc";
                    }
                }
                else{
                    if($date_column{$_}){
                        if($_ =~ /(\w+)\_end$/){
                            $date_hash->{ $1 }->{ date_end } = $params->{$_};
                        }
                        else{
                            $date_hash->{ $_ }->{ date_start } = $params->{$_} ;
                        }
                    }
                    else{
                        $params->{$_} = uc $params->{$_};
                        $sql->{1}     .= qq( and upper(stuff_tracker.$_) like '%$params->{$_}%' );
                        $sql->{count} .= qq( and upper(stuff_tracker.$_) like '%$params->{$_}%' );
                    }
                }
            }
        }
    }

    if($rid){
        if($rid =~ /^\d+$/){
            $sql->{1} .= qq( and stuff_tracker.stuff_tracker_id = $rid );
        }    
    }    

    ## Filter Dates
    my $date_hash_not_empty = undef;
    $date_hash_not_empty    = (keys %$date_hash)[-1];
    
    if($date_hash_not_empty){
        for(keys %$date_hash){
            $sql->{1}     .= " and stuff_tracker.$_ between '$date_hash->{$_}->{date_start}' and '$date_hash->{$_}->{date_end}' ";
            $sql->{count} .= " and stuff_tracker.$_ between '$date_hash->{$_}->{date_start}' and '$date_hash->{$_}->{date_end}' ";
        }
    }

    if($sort_by){
        $sql->{1} .= qq( order by $sort_by $sort_order );
    }

    $sql->{1} .= " LIMIT $limit OFFSET $offset ";

    $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
    $sth->{1}->execute() or error("Error in sth_1 execute");
    my $sql_1_result = $sth->{1}->fetchall_arrayref({});
    $sth->{1}->finish;

    if(not defined($rid)){
        $sth->{count} = $dbh->prepare($sql->{count}) or error("Error in sth_count");
        $sth->{count}->execute() or error("Error in sth_count");
        my $sql_count_result = $sth->{count}->fetchrow_arrayref;
        $sth->{count}->finish;
        $result_count = $sql_count_result->[0];
    }

    $dbh->disconnect;

    if($output){

        my $result_array = [];

        my $user_hash = &_db_authen_fetch_user();

        for my $row (@$sql_1_result){

            my @result_array_temp = (); 

            for my $column_name (@csv_column_array){
                if($row->{$column_name}){
                    if($column_name eq "integrated_by"){
                        $row->{integrated_by} = $user_hash->{ $row->{integrated_by} };
                        push @result_array_temp, $row->{"integrated_by"};
                    }
                    elsif($column_name eq "updated_by"){
                        $row->{updated_by} = $user_hash->{ $row->{updated_by} };
                        push @result_array_temp, $row->{"updated_by"};
                    }
                    else{
                        $row->{$column_name} =~ s/\"/ /g;
                        $row->{$column_name} =~ s/\n//g;
                        $row->{$column_name} =~ s/\r\n//g;
                        push @result_array_temp, $row->{$column_name};
                    }
                }
            }

            my $result_row = qq(");
            $result_row .= join("\";\"", @result_array_temp);
            $result_row .= qq("\n);

            push @$result_array, $result_row;
        }

        my $title = qq(sep=;\n");
        $title .= join("\";\"", @csv_title_array);
        $title .= qq("\n);

        unshift @$result_array, $title;

        return ({csv_output => $result_array});
    }
    else{
        if(defined($rid)){

            my $user_hash = &_db_authen_fetch_user();

            my $result_array = [];

            for my $row (@$sql_1_result){
                if( (defined($row->{integrated_by})) || (defined($row->{updated_by})) ){
                    $row->{integrated_by_name} = $user_hash->{ $row->{integrated_by} };
                    $row->{updated_by_name}    = $user_hash->{ $row->{updated_by} };
                }
                push @$result_array, $row;
            }

            return ({ json_output => to_json($result_array, {utf8 => 0}) });
        }
        else{

            my $user_hash = &_db_authen_fetch_user();

            my $result_array = [];

            for my $row (@$sql_1_result){
                if( (defined($row->{integrated_by})) || (defined($row->{updated_by})) ){
                    $row->{integrated_by_name} = $user_hash->{ $row->{integrated_by} };
                    $row->{updated_by_name}    = $user_hash->{ $row->{updated_by} };
                }
                push @$result_array, $row;
            }

            return ({ json_output   => to_json($result_array, {utf8 => 0}),
                      content_range => $content_range,
                      result_count  => $result_count });
        }
    }
}

sub stuff_tracker_columns {
    
    my ($sub_hash) = @_;
    
    my $dbh = &_db_handle($db_hash);
    my $sql = {};
    my $sth = {};

    my $result_array = [];

    $sql->{1} = qq(select 
                    a.db_column_id as id,
                    a.name as name,
                    a.description as description,
                    a.column_size,
                    a.column_order,
                    b.name as type
                   from
                    db_column a,
                    db_column_type b
                   where
                    b.db_column_type_id = a.db_column_type_to_db_column_id
                    and a.status_to_db_column_id = ?
                    order by a.column_order);

    $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
    $sth->{1}->execute(1) or error("Error in sth_1 execute");
    my $sql_1_result = $sth->{1}->fetchall_arrayref({});

    for my $row (@$sql_1_result){

        my $protected = undef;

        if($row->{name} eq "integrated_by"){
            $protected = 1;
        }

        if($row->{name} eq "updated_by"){
            $protected = 1;
        }

        push @$result_array, { id          => $row->{id}, 
                               name        => $row->{name},
                               description => $row->{description},
                               size        => $row->{column_size},
                               order       => $row->{column_order},
                               protected   => $protected,
                               type        => $row->{type} };
    }

    $sth->{1}->finish;
    $dbh->disconnect;

     return ({ json_output => to_json($result_array, {utf8 => 0}) });
}

sub add_stuff {

    my ($sub_hash) = @_;

    my $dbh = &_db_handle($db_hash);
    my $sth = {};
    my $sql = {};

    my $column_hash = {};

    my $sub_output = "Error addding host!";

    $sql->{1} = qq(select 
                    a.name as column,
                    b.name as column_type
                   from
                    db_column a,
                    db_column_type b
                   where
                    b.db_column_type_id = a.db_column_type_to_db_column_id
                    and a.status_to_db_column_id = ?);

    $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
    $sth->{1}->execute(1) or error("Error in sth_1 execute");
    my $sql_1_result = $sth->{1}->fetchall_arrayref({});

    for my $row (@$sql_1_result){
        if($sub_hash->{ $row->{column} }){

            my $column_name = $row->{column};
            my $column_type = $row->{column_type};

            if($column_type eq "select"){
                $column_name = $column_name . "_to_stuff_tracker_id";
            }

            $column_hash->{ $column_name } = $sub_hash->{ $row->{column} };
        }
    }

    my $column_hash_not_empty = undef;
    $column_hash_not_empty    = (keys %$column_hash)[-1];

    if($column_hash_not_empty){

        $sql->{1} = "insert into stuff_tracker (created) values (" . &_now_to_use() . ")";
        $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
        $sth->{1}->execute() or error("Error in sth_1 execute");
        $sth->{1}->finish;

        my $last_id = $dbh->last_insert_id(undef,undef,"stuff_tracker",undef) || undef;

        if($last_id){

            $sub_output = "Added entry successfully!";
             
            for my $column (keys %$column_hash){

                $sql->{2} = qq(update stuff_tracker set $column = ? where stuff_tracker_id = ?);
                $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
                $sth->{2} = $sth->{2}->execute($column_hash->{ $column },$last_id) or error("Error in sth_2 execute");
            }
        }
    }
    $dbh->disconnect;
    return $sub_output;
}

sub modify_stuff {

    my ($sub_hash) = @_;

    my $dbh = &_db_handle($db_hash);
    my $sth = {};
    my $sql = {};

    my $column_hash = {};

    $sql->{1} = qq(select 
                    a.name as column,
                    b.name as column_type
                   from
                    db_column a,
                    db_column_type b
                   where
                    b.db_column_type_id = a.db_column_type_to_db_column_id
                    and a.status_to_db_column_id = ?);

    $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
    $sth->{1}->execute(1) or error("Error in sth_1 execute");
    my $sql_1_result = $sth->{1}->fetchall_arrayref({});

    for my $row (@$sql_1_result){

        my $column = $row->{column};
        my $type   = $row->{column_type};
        my $value  = $sub_hash->{ $row->{column} } || "_NULL_";

        $column_hash->{ $column } = { type  => $type,
                                      value => $value };
    }

    my $column_hash_not_empty = undef;
    $column_hash_not_empty    = (keys %$column_hash)[-1];

    if($column_hash_not_empty){

        for my $column (keys %$column_hash){

            my $column_name  = $column;
            my $column_type  = $column_hash->{$column}->{type};
            my $column_value = $column_hash->{$column}->{value};

            $sql->{1} = qq(select $column_name as column from stuff_tracker where stuff_tracker_id = ?);
            $sql->{2} = "update stuff_tracker set updated = " . &_now_to_use() . ", $column_name = ? where stuff_tracker_id = ?";

            if(defined($column_hash->{$column}->{type})){
                if($column_hash->{$column}->{type} eq "date"){
                    if(config->{"dbi_to_use"} ne "SQLite"){
                        $sql->{1} = qq(select 
                                        to_char($column,'YYYY-MM-DD') as column
                                       from stuff_tracker where stuff_tracker_id = ?);
                    }
                }
                if($column_hash->{$column}->{type} eq "select"){

                    my $e_column_name = $column_name . "_to_stuff_tracker_id";
                    $sql->{1} = qq(select $e_column_name as column from stuff_tracker where stuff_tracker_id = ?);
                    $sql->{2} = undef;

                    ## Verify if value is valid in Foreign Column
                    my $f_column_name_id = $column_name . "_id";
                    $sql->{3} = qq(select $f_column_name_id as fid from $column_name where description = ?);
                    $sth->{3} = $dbh->prepare($sql->{3}) or error("Error in sth_3");
                    $sth->{3}->execute($column_value) or error("Error in sth_3");
                    my $sql_result = $sth->{3}->fetchrow_hashref || {};
                    $sth->{3}->finish;

                    if($sql_result->{fid}){
                        $column_value = $sql_result->{fid};
                        $sql->{2} = "update stuff_tracker set updated = " . &_now_to_use() . ", $e_column_name = ? where stuff_tracker_id = ?";
                    }
                }
            }

            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute($sub_hash->{id}) or error("Error in sth_1");
            my $sql_result = $sth->{1}->fetchrow_hashref || {};
            $sth->{1}->finish;

            my $sql_result_value = $sql_result->{column} || "_NULL_";

            ## Update
            if($sql->{2}){
                $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");

                if($column_value ne $sql_result_value){
                    if($column_value eq "_NULL_"){
                        $sth->{2}->execute(undef,$sub_hash->{id}) or error("Error in sth_2");
                    }
                    else{
                        $sth->{2}->execute($column_value,$sub_hash->{id}) or error("Error in sth_2");
                    }
                }
                $sth->{2}->finish;
            }
        }
    }
    $dbh->disconnect;
}

sub delete_stuff {

    my ($sub_hash) = @_;

    my $dbh = &_db_handle($db_hash);
    my $sth = {};
    my $sql = {};

    my $sub_output = "Error deleting entry!";

    my $rid = $sub_hash->{rid};

    if($sub_hash->{rid}){

        $sql->{1} = qq(delete from stuff_tracker where stuff_tracker_id = ?);
        $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
        $sth->{1}->execute($sub_hash->{rid}) or error("Error in sth_1 execute");
        $sth->{1}->finish;

        $sub_output = "Deleted entry successfully!";
    }
    $dbh->disconnect;
    return $sub_output;
}

sub filtering_select {

    my ($sub_hash) = @_;
    
    my $input = $sub_hash->{input} || undef;
    my $name  = $sub_hash->{name}     || undef;
    my $gid   = $sub_hash->{gid}      || undef;
    
    my $dbh = &_db_handle($db_hash);
    my $sth = {};
    my $sql = {};
    
    my $result_array = [];

    if($input){

        if( ($input eq "integrated_by") || ($input eq "updated_by") ){

            my $result_hash = &_db_authen_fetch_user();

            my $first_key = undef;
            my $first_val = undef;
            
            my $sort_by   = undef;

            ## Sort by key
            if($gid){
                if($gid =~ /^\d+$/){
                    if($result_hash->{ $gid }){
                        $first_val = $result_hash->{ $gid };
                        delete $result_hash->{ $gid };
                        $sort_by = 'key';
                    }
                }
            }
            
            ## Sort by value
            if($name){
                for(keys %$result_hash){
                    if($result_hash->{$_} eq $name){
                        $first_key = $_;
                        delete $result_hash->{ $_ };
                        $sort_by = 'val';
                        last;
                    }
                }
            }
            
            for(sort { $result_hash->{$a} cmp $result_hash->{$b} } keys %$result_hash){
                push @$result_array, { id => $_, name => $result_hash->{$_} };
            }
            
            if($sort_by){
                if($sort_by eq 'key'){
                    unshift @$result_array, { id => $gid, name => $first_val};
                }
                if($sort_by eq 'val'){
                    unshift @$result_array, { id => $first_key, name => $name};
                }
            }
        }
        elsif($input eq "column_type"){

            $sql->{1} = qq(select db_column_type_id as id,name from db_column_type);
            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute() or error("Error in sth_1 execute");
            my $sql_1_result = $sth->{1}->fetchall_arrayref({});
            $sth->{1}->finish;

            my $result_hash = {};
            
            my $first_key = undef;
            my $first_val = undef;
            
            my $sort_by   = undef;
            
            for my $row (@$sql_1_result){
                $result_hash->{ $row->{id} } = $row->{name};
            }
            
            ## Sort by key
            if($gid){
                if($gid =~ /^\d+$/){
                    if($result_hash->{ $gid }){
                        $first_val = $result_hash->{ $gid };
                        delete $result_hash->{ $gid };
                        $sort_by = 'key';
                    }
                }
            }
            
            ## Sort by value
            if($name){
                for(keys %$result_hash){
                    if($result_hash->{$_} eq $name){
                        $first_key = $_;
                        delete $result_hash->{ $_ };
                        $sort_by = 'val';
                        last;
                    }
                }
            }
            
            for(sort { $result_hash->{$a} cmp $result_hash->{$b} } keys %$result_hash){
                push @$result_array, { id => $_, name => $result_hash->{$_} };
            }
            
            if($sort_by){
                if($sort_by eq 'key'){
                    unshift @$result_array, { id => $gid, name => $first_val};
                }
                if($sort_by eq 'val'){
                    unshift @$result_array, { id => $first_key, name => $name};
                }
            }
        }
        else{

            $sql->{1} = qq(select name from db_column where db_column_id = ?);
            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute($input) or error("Error in sth_1 execute");
            my $sql_1_result = $sth->{1}->fetchrow_hashref;
            $sth->{1}->finish;

            my $table = $sql_1_result->{name};

            my $column_id     = $table . "_id";
            my $column_status = "status_to_" . $table . "_id";

            $sql->{2} = qq(select $column_id as id,description from $table 
                           where $column_status = 1 order by description);
            $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
            $sth->{2}->execute() or error("Error in sth_2 execute");
            my $sql_2_result = $sth->{2}->fetchall_arrayref({}) || [];
            $sth->{2}->finish;

            my $result_hash = {};
            
            my $first_key = undef;
            my $first_val = undef;
            
            my $sort_by   = undef;
            
            for my $row (@$sql_2_result){
                $result_hash->{ $row->{id} } = $row->{description};
            }
            
            
            ## Sort by key
            if($gid){
                if($gid =~ /^\d+$/){
                    if($result_hash->{ $gid }){
                        $first_val = $result_hash->{ $gid };
                        delete $result_hash->{ $gid };
                        $sort_by = 'key';
                    }
                }
            }
            
            ## Sort by value
            if($name){
                for(keys %$result_hash){
                    if($result_hash->{$_} eq $name){
                        $first_key = $_;
                        delete $result_hash->{ $_ };
                        $sort_by = 'val';
                        last;
                    }
                }
            }
            
            for(sort { $result_hash->{$a} cmp $result_hash->{$b} } keys %$result_hash){
                push @$result_array, { id => $_, name => $result_hash->{$_} };
            }
            
            if($sort_by){
                if($sort_by eq 'key'){
                    unshift @$result_array, { id => $gid, name => $first_val};
                }
                if($sort_by eq 'val'){
                    unshift @$result_array, { id => $first_key, name => $name};
                }
            }
        }    
    }
    $dbh->disconnect;

    return ({ json_output => to_json($result_array, {utf8 => 0}) });
}

sub admin_grid {
    
    my ($sub_hash) = @_;
    
    my $content_range = $sub_hash->{content_range} || undef;
    my $column_id     = $sub_hash->{column_id}     || undef;

    my $dbh = &_db_handle($db_hash);
    my $sql = {};
    my $sth = {};

    my $result_array = [];

    ## Paging
    my $limit        = "100";
    my $offset       = "0";
    my $result_count = "";

    if( (defined($content_range)) && ($content_range =~ /items\=(\d+)\-(\d+)/) ){
        $offset = $1;
    }

    if(session->read('session_admin') == 1){
        if($column_id){

            $sql->{1} = qq(select name as table_name from db_column where db_column_id = ?);
            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute($column_id) or error("Error in sth_1 execute");
            my $sql_1_result = $sth->{1}->fetchrow_hashref;
            $sth->{1}->finish;

            my $table      = $sql_1_result->{table_name};
            my $table_id   = $table . "_id";
            my $row_status = "status_to_" . $table . "_id";

            $sql->{2} = qq(select $table_id as id, description, $row_status as status from $table);
            $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
            $sth->{2}->execute() or error("Error in sth_2 execute");
            my $sql_2_result = $sth->{2}->fetchall_arrayref({});

            for my $row (@$sql_2_result){

                my $status = $row->{status} || 2;
                
                if($status eq 1){
                    $status = bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' );
                }
                else{
                    $status = bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' );
                }

                push @$result_array, { id             => $row->{id}, 
                                       description    => $row->{description},
                                       status         => $status };
            }
            $sth->{2}->finish;

            $sql->{count} = qq(select count($table_id) from $table);
            $sth->{count} = $dbh->prepare($sql->{count}) or error("Error in sth_count");
            $sth->{count}->execute() or error("Error in sth_count");
            my $sql_count_result = $sth->{count}->fetchrow_arrayref;
            $sth->{count}->finish;
            $result_count = $sql_count_result->[0];
        }
    }

    $dbh->disconnect;

    return ({ json_output   => to_json($result_array, {utf8 => 0}),
              content_range => $content_range,
              result_count  => $result_count });
}

sub admin_add {

    my ($sub_hash) = @_;

    my $column_id   = $sub_hash->{column_id}   || undef;
    my $description = $sub_hash->{description} || undef;

    my $dbh = &_db_handle($db_hash);
    my $sth = {};
    my $sql = {};

    my $sub_output = "Error addding host!";

    if(session->read('session_admin') == 1){
        if($column_id){

            $sql->{1} = qq(select name as table_name from db_column where db_column_id = ?);
            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute($column_id) or error("Error in sth_1 execute");
            my $sql_1_result = $sth->{1}->fetchrow_hashref;
            $sth->{1}->finish;

            my $table = $sql_1_result->{table_name};

            $sql->{2} = qq(insert into $table (description) values (?));
            $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
            $sth->{2}->execute($description) or error("Error in sth_2 execute");
            $sth->{2}->finish;

            my $current_host_id = $dbh->last_insert_id(undef,undef,$table,undef) || undef;

            if($current_host_id){
                $sub_output = "Added Description \"$description\" successfully!";
            }
        }
    }

    $dbh->disconnect;
    return $sub_output;
}

sub modify_admin {

    my ($sub_hash) = @_;

    my $column_id   = $sub_hash->{column_id}   || undef;

    my $id          = $sub_hash->{id}          || undef;
    my $description = $sub_hash->{description} || "_NULL_";
    my $status      = $sub_hash->{status}      || 2;

    my $dbh = &_db_handle($db_hash);
    my $sth = {};
    my $sql = {};

    if(session->read('session_admin') == 1){
        if($id){

            $sql->{1} = qq(select name as table_name from db_column where db_column_id = ?);
            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute($column_id) or error("Error in sth_1 execute");
            my $sql_1_result = $sth->{1}->fetchrow_hashref;
            $sth->{1}->finish;

            my $table    = $sql_1_result->{table_name};
            my $table_id = $table . "_id";

            ## Description

            $sql->{2} = qq(select description from $table where $table_id = ?);
            $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
            $sth->{2}->execute($id) or error("Error in sth_2");
            my $sql_result_2 = $sth->{2}->fetchrow_hashref || {};
            $sth->{2}->finish;

            if($description ne $sql_result_2->{description}){

                $sql->{3} = qq(update $table set description = ? where $table_id = ?);
                $sth->{3} = $dbh->prepare($sql->{3}) or error("Error in sth_3");

                if($description eq "_NULL_"){
                    $sth->{3}->execute(undef,$id) or error("Error in sth_3");
                }
                else{
                    $sth->{3}->execute($description,$id) or error("Error in sth_3");
                }
                $sth->{3}->finish;
            }

            ## Status

            my $status_column  = "status_to_" . $table . "_id";

            $sql->{4} = qq(select $status_column as status from $table where $table_id = ?);
            $sth->{4} = $dbh->prepare($sql->{4}) or error("Error in sth_4");
            $sth->{4}->execute($id) or error("Error in sth_4");
            my $sql_result_4 = $sth->{4}->fetchrow_hashref || {};
            $sth->{4}->finish;

            if($status ne $sql_result_4->{status}){

                if($status != 2){
                    $status = 1;
                }

                $sql->{5} = qq(update $table set $status_column = ? where $table_id = ?);
                $sth->{5} = $dbh->prepare($sql->{5}) or error("Error in sth_5");
                $sth->{5}->execute($status,$id) or error("Error in sth_5");
                $sth->{5}->finish;
            }
        }
    }

    $dbh->disconnect;
}

sub column_grid {
    
    my ($sub_hash) = @_;
    
    my $content_range = $sub_hash->{content_range} || undef;

    my $dbh = &_db_handle($db_hash);
    my $sql = {};
    my $sth = {};

    my $result_array = [];

    ## Paging
    my $limit        = "100";
    my $offset       = "0";
    my $result_count = "";

    if( (defined($content_range)) && ($content_range =~ /items\=(\d+)\-(\d+)/) ){
        $offset = $1;
    }

    if(session->read('session_admin') == 1){

        $sql->{1} = qq(select 
                        a.db_column_id as id,
                        a.name,
                        a.description,
                        a.column_size,
                        a.column_order,
                        a.status_to_db_column_id as status,
                        b.description as type
                       from 
                        db_column a,
                        db_column_type b
                       where 
                        b.db_column_type_id = a.db_column_type_to_db_column_id
                        order by a.column_order);
        $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
        $sth->{1}->execute() or error("Error in sth_1 execute");
        my $sql_1_result = $sth->{1}->fetchall_arrayref({});
        $sth->{1}->finish;

        for my $row (@$sql_1_result){

            my $status = $row->{status} || 2;
            
            if($status eq 1){
                $status = bless( do{\(my $o = 1)}, 'JSON::XS::Boolean' );
            }
            else{
                $status = bless( do{\(my $o = 0)}, 'JSON::XS::Boolean' );
            }

            push @$result_array, { id          => $row->{id}, 
                                   name        => $row->{name},
                                   description => $row->{description},
                                   size        => $row->{column_size},
                                   order       => $row->{column_order},
                                   status      => $status,
                                   type        => $row->{type} };
        }
        $sth->{1}->finish;

        $sql->{count} = qq(select 
                            count(a.db_column_id)
                           from 
                            db_column a,
                            db_column_type b
                           where 
                            b.db_column_type_id = a.db_column_type_to_db_column_id);
        $sth->{count} = $dbh->prepare($sql->{count}) or error("Error in sth_count");
        $sth->{count}->execute() or error("Error in sth_count");
        my $sql_count_result = $sth->{count}->fetchrow_arrayref;
        $sth->{count}->finish;
        $result_count = $sql_count_result->[0];
    }

    $dbh->disconnect;

    return ({ json_output   => to_json($result_array, {utf8 => 0}),
              content_range => $content_range,
              result_count  => $result_count });
}

sub column_admin {

    my ($sub_hash) = @_;

    my $dbh = &_db_handle($db_hash);
    my $sth = {};
    my $sql = {};

    my $sub_output = "Error addding column!";

    if(session->read('session_admin') == 1){

        if($sub_hash->{action} eq "add"){

            $sql->{1} = qq(select name as type from db_column_type where db_column_type_id = ?);
            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute($sub_hash->{type}) or error("Error in sth_1 execute");
            my $sql_1_result = $sth->{1}->fetchrow_hashref;
            $sth->{1}->finish;

            $sql->{2} = qq(select db_column_id from db_column where description = ?);
            $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
            $sth->{2}->execute($sub_hash->{description}) or error("Error in sth_2 execute");
            my $sql_2_result = $sth->{2}->fetchrow_hashref;
            $sth->{2}->finish;

            if(!$sql_2_result->{db_column_id}){

                my $new_column = &_fetch_new_column_name();

                $sql->{3} = qq(insert into db_column (name,description,db_column_type_to_db_column_id) values (?,?,?));
                $sth->{3} = $dbh->prepare($sql->{3}) or error("Error in sth_3");
                $sth->{3}->execute($new_column,$sub_hash->{description},$sub_hash->{type}) or error("Error in sth_3 execute");
                $sth->{3}->finish;

                if($sql_1_result->{type} eq "varchar"){
                    $sql->{4} = qq(alter table stuff_tracker add column $new_column varchar(100) null);
                    $sth->{4} = $dbh->prepare($sql->{4}) or error("Error in sth_4");
                    $sth->{4}->execute() or error("Error in sth_4 execute");
                    $sth->{4}->finish;
                }
                if($sql_1_result->{type} eq "integer"){
                    $sql->{4} = qq(alter table stuff_tracker add column $new_column int4 null);
                    $sth->{4} = $dbh->prepare($sql->{4}) or error("Error in sth_4");
                    $sth->{4}->execute() or error("Error in sth_4 execute");
                    $sth->{4}->finish;
                }
                if($sql_1_result->{type} eq "date"){
                    $sql->{4} = qq(alter table stuff_tracker add column $new_column timestamp null);
                    $sth->{4} = $dbh->prepare($sql->{4}) or error("Error in sth_4");
                    $sth->{4}->execute() or error("Error in sth_4 execute");
                    $sth->{4}->finish;
                }

                if($sql_1_result->{type} eq "select"){

                    if(config->{"dbi_to_use"} eq "SQLite"){

                        my $table_name        = $new_column;
                        my $table_name_id     = $table_name . "_id";
                        my $table_name_status = "status_to_" . $table_name_id;
                        my $column_name       = $new_column . "_to_stuff_tracker_id";
                        my $primary_key       = &_primary_key_to_use();

                        my %statement_hash = ( 
                            5 => qq(CREATE TABLE $table_name (
                                        $table_name_id $primary_key, 
                                        description varchar(100) not null,
                                        $table_name_status int4 not null DEFAULT 1,
                                        FOREIGN KEY ($table_name_status) REFERENCES status (status_id))),
                            6 => qq(INSERT INTO $table_name (description) VALUES ('default')),
                            7 => qq(ALTER TABLE stuff_tracker ADD COLUMN $column_name int4 null DEFAULT 1)
                        );

                        for my $key (sort {$a <=> $b} keys %statement_hash){
                            $sql->{$key} = $statement_hash{$key};
                            $sth->{$key} = $dbh->prepare($sql->{$key}) or error("Error in sth_$key");
                            $sth->{$key}->execute() or error("Error in sth_$key execute");
                            $sth->{$key}->finish;
                        }

                        my @column_name_array = ();
                        my @column_array      = ();
                        my @f_column_array    = ();

                        $sql->{8} = qq(select 
                                       a.name as column_name,
                                       a.description as column_description,
                                       b.name as column_type 
                                      from 
                                       db_column a,
                                       db_column_type b
                                      where 
                                       b.db_column_type_id = a.db_column_type_to_db_column_id);
                        $sth->{8} = $dbh->prepare($sql->{8}) or error("Error in sth_8");
                        $sth->{8}->execute() or error("Error in sth_8 execute");
                        my $sql_8_result = $sth->{8}->fetchall_arrayref({});
                        $sth->{8}->finish;

                        for my $row (@$sql_8_result){
                            
                            if($row->{column_type} eq "varchar"){
                                push @column_array, "$row->{column_name} varchar(100) null";
                                push @column_name_array, $row->{column_name};
                            }
                            if($row->{column_type} eq "integer"){
                                push @column_array, "$row->{column_name} int4 null";
                                push @column_name_array, $row->{column_name};
                            }
                            if($row->{column_type} eq "date"){
                                push @column_array, "$row->{column_name} timestamp null";
                                push @column_name_array, $row->{column_name};
                            }
                            if($row->{column_type} eq "select"){
                                my $column_name = $row->{column_name} . "_to_stuff_tracker_id";
                                my $column_id   = $row->{column_name} . "_id";
                                push @column_array, "$column_name int4 null";
                                push @f_column_array, "FOREIGN KEY ($column_name) references $row->{column_name} ($column_id)";
                                push @column_name_array, $column_name;
                            }
                        }

                        ## create select string

                        my $column_string = qq(stuff_tracker_id,created,updated);

                        if($column_name_array[0]){
                            if($column_name_array[1]){
                                $column_string .=  ",";
                                my $last_one = pop @column_name_array;
                                for my $row (@column_name_array){
                                    $column_string .=  " $row, ";
                                }
                                $column_string .=  " $last_one ";
                            }
                            else{
                                $column_string .=  ", $column_name_array[0] ";
                            }
                        }

                        $sql->{9} = qq(create temporary table stuff_tracker_b as select $column_string from stuff_tracker);
                        $sth->{9} = $dbh->prepare($sql->{9}) or error("Error in sth_9");
                        $sth->{9}->execute() or error("Error in sth_9 execute");
                        $sth->{9}->finish;

                        $sql->{10} = qq(drop table stuff_tracker);
                        $sth->{10} = $dbh->prepare($sql->{10}) or error("Error in sth_10");
                        $sth->{10}->execute() or error("Error in sth_10 execute");
                        $sth->{10}->finish;

                        ## create table

                        $sql->{main} = qq{create table stuff_tracker(stuff_tracker_id integer primary key, created timestamp not null, updated timestamp null};

                        if($column_array[0]){
                            if($column_array[1]){
                                $sql->{main} .= ",";
                                my $last_one = pop @column_array;
                                for my $row (@column_array){
                                    $sql->{main} .= " $row, ";
                                }
                                $sql->{main} .=  " $last_one ";
                            }
                            else{
                                $sql->{main} .= ", $column_array[0] ";
                            }
                        }

                        if($f_column_array[0]){
                            if($f_column_array[1]){
                                $sql->{main} .= ",";
                                my $last_one = pop @f_column_array;
                                for my $row (@f_column_array){
                                    $sql->{main} .= " $row, ";
                                }
                                $sql->{main} .= " $last_one ";
                            }
                            else{
                                $sql->{main} .= ", $f_column_array[0] ";
                            }
                        }

                        $sql->{main} .=  " ) ";

                        $sth->{main} = $dbh->prepare($sql->{main}) or error("Error in sth_main");
                        $sth->{main}->execute() or error("Error in sth_main execute");
                        $sth->{main}->finish;

                        $sql->{11} = qq{insert into stuff_tracker ($column_string) select $column_string from stuff_tracker_b};
                        $sth->{11} = $dbh->prepare($sql->{11}) or error("Error in sth_11");
                        $sth->{11}->execute() or error("Error in sth_11 execute");
                        $sth->{11}->finish;
                    }
                    else{

                        my $table_name        = $new_column;
                        my $table_name_id     = $table_name . "_id";
                        my $table_name_status = "status_to_" . $table_name_id;

                        my $column_name       = $new_column . "_to_stuff_tracker_id";
                        my $constraint_name   = "stuff_tracker_" . $new_column . "_to_stuff_tracker_id_fkey";

                        my $primary_key       = &_primary_key_to_use();

                        my %statement_hash = ( 
                            5 => qq(CREATE TABLE $table_name (
                                        $table_name_id $primary_key, 
                                        description varchar(100) not null,
                                        $table_name_status int4 not null DEFAULT 1,
                                        FOREIGN KEY ($table_name_status) REFERENCES status (status_id))),
                            6 => qq(INSERT INTO $table_name (description) VALUES ('default')),
                            7 => qq(ALTER TABLE stuff_tracker ADD COLUMN $column_name int4 null DEFAULT 1),
                            8 => qq(ALTER TABLE stuff_tracker ADD CONSTRAINT $constraint_name FOREIGN KEY ($column_name) REFERENCES $table_name ($table_name_id) MATCH SIMPLE)
                        );

                        for my $key (sort {$a <=> $b} keys %statement_hash){
                            $sql->{$key} = $statement_hash{$key};
                            $sth->{$key} = $dbh->prepare($sql->{$key}) or error("Error in sth_$key");
                            $sth->{$key}->execute() or error("Error in sth_$key execute");
                            $sth->{$key}->finish;
                        }
                    }
                }
                $sub_output = "Added column \"$sub_hash->{description}\" successfully!";
            }
        }

        if($sub_hash->{action} eq "edit"){

            my $status = $sub_hash->{status} || 2; 

            $sql->{1} = qq(select 
                            a.description,
                            a.column_size,
                            a.column_order,
                            a.status_to_db_column_id as status,
                            a.db_column_type_to_db_column_id as type_id,
                            b.name as type
                           from 
                            db_column a,
                            db_column_type b
                           where 
                            b.db_column_type_id = a.db_column_type_to_db_column_id
                            and a.db_column_id = ?);

            $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
            $sth->{1}->execute($sub_hash->{id}) or error("Error in sth_1 execute");
            my $sql_1_result = $sth->{1}->fetchrow_hashref;
            $sth->{1}->finish;

            if($sql_1_result->{description}){

                ## Order
                if($sql_1_result->{column_order} ne $sub_hash->{order}){
                    $sql->{2} = qq(update db_column set column_order = ? where db_column_id = ?);
                    $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
                    $sth->{2}->execute($sub_hash->{order},$sub_hash->{id}) or error("Error in sth_2 execute");
                    $sth->{2}->finish;
                    $sub_output = "Edited column from \"$sql_1_result->{column_order}\" to \"$sub_hash->{order}\" successfully!";
                }

                ## Size
                if($sql_1_result->{column_size} ne $sub_hash->{size}){
                    $sql->{2} = qq(update db_column set column_size = ? where db_column_id = ?);
                    $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
                    $sth->{2}->execute($sub_hash->{size},$sub_hash->{id}) or error("Error in sth_2 execute");
                    $sth->{2}->finish;
                    $sub_output = "Edited column from \"$sql_1_result->{column_size}\" to \"$sub_hash->{size}\" successfully!";
                }

                ## Status
                if($sql_1_result->{status} ne $status){

                    if($status != 2){
                        $status = 1;
                    }

                    $sql->{2} = qq(update db_column set status_to_db_column_id = ? where db_column_id = ?);
                    $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
                    $sth->{2}->execute($status,$sub_hash->{id}) or error("Error in sth_2 execute");
                    $sth->{2}->finish;
                }

                ## Name
                if($sql_1_result->{description} ne $sub_hash->{description}){

                    $sql->{2} = qq(update db_column set description = ? where db_column_id = ?);
                    $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
                    $sth->{2}->execute($sub_hash->{description},$sub_hash->{id}) or error("Error in sth_2 execute");
                    $sth->{2}->finish;

                    $sub_output = "Edited column from \"$sql_1_result->{description}\" to \"$sub_hash->{description}\" successfully!";
                }
            }
        }
    }

    $dbh->disconnect;
}

sub _db_handle {

    my ($db_hash) = @_;

    my $dbh = undef;

    if($db_hash->{dbi_to_use} eq "SQLite"){
        $dbh = DBI->connect("dbi:$db_hash->{dbi_to_use}:dbname=$db_hash->{db}","","", {RaiseError => 1}) or croak("Could not connect to DB: $DBI::errstr");
        $dbh->{sqlite_unicode} = 1;
    }
    else{
        $dbh = DBI->connect("dbi:$db_hash->{dbi_to_use}:dbname=$db_hash->{db};host=$db_hash->{host};port=$db_hash->{port};","$db_hash->{username}","$db_hash->{password}") or croak("Could not connect to DB: $DBI::errstr");
    }
    
    return $dbh;
}

sub _now_to_use {

    my $result = 'NOW()';

    if(config->{"dbi_to_use"} eq "SQLite"){
        $result = '(datetime(\'now\',\'localtime\'))';
    }
    return $result;
}

sub _primary_key_to_use {

    my $result = 'serial primary key';

    if(config->{"dbi_to_use"} eq "SQLite"){
        $result = 'integer primary key';
    }
    if(config->{"dbi_to_use"} eq "mysql"){
        $result = 'int auto_increment primary key';
    }
    return $result;
}

sub _fetch_new_column_name{

    my ($sub_hash) = @_;
    
    my $dbh = &_db_handle($db_hash);
    my $sql = {};
    my $sth = {};

    my %order_hash = ();

    $sql->{1} = qq(select name from db_column);
    $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
    $sth->{1}->execute() or error("Error in sth_1 execute");
    my $sql_1_result = $sth->{1}->fetchall_arrayref({});
    $sth->{1}->finish;
    $dbh->disconnect;

    for my $row (@$sql_1_result){
        if($row->{name} =~ /\w+\_(\d+)/){
            my $order = $1;
            $order_hash{$order} = $order;
        }
    }

    my $last = (sort {$a<=>$b} keys %order_hash)[-1];
    $last = $last + 1;

     return "column_" . $last;
}

sub _generate_password{
    
    my ($sub_hash) = @_;
    
    my $password = $sub_hash->{password} || undef;
    
    if(!$password){
        $password = &_generate_random_string('16');
    }    

    my $result = md5_hex($password);
    
    return $result;
}

sub _generate_random_string{
    
     my $length_of_randomstring = shift;
     my @chars=('a'..'z','A'..'Z','0'..'9');
     my $random_string;
 
     for(my $i = 0; $i < $length_of_randomstring; $i++){
       $random_string .= $chars[int(rand(58))];
     }    
 
     return $random_string;
}

## Login

sub _db_authen_process_login {
    
	my ($sub_hash) = @_;
    
    my $username = $sub_hash->{username};
    my $password = $sub_hash->{password};
    
    my $sub_output = { session_authorized => 2, 
                       session_admin      => 2, 
                       login_message      => "User not authorized to login on this page." };
    
    if($username){
        my $user_exists = &_db_authen_fetch_user({ username => $username });
        if($user_exists->{id}){
            debug("User exists in DB");
            debug("Testing Authentication with DB");
            if($user_exists->{password} eq md5_hex($password)){
                debug("User authenticated with DB");
                $sub_output = { username           => $username,
                                uid                => $user_exists->{id},
                                fullname           => $user_exists->{fullname},
                                privilege          => $user_exists->{privilege},
                                session_authorized => 1,
                                login_message      => "Logged in successfully" };
            }
            else{
                $sub_output->{login_message} = "Wrong password; please try again";
            }
        }
    }
    return $sub_output;
}

sub _db_authen_fetch_user_orig {

    my ($sub_hash) = @_;

    my $dbh = &_db_handle($db_auth_hash);
    my $sth = {};
    my $sql = {};

    $sql->{1} = qq(select user_manager_id,username,password,real_name,privilege_to_user_manager_id as privilege from user_manager where username = ?);
    $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
    $sth->{1}->execute($sub_hash->{username}) or error("Error in sth_1 execute");
    my $sql_1_result = $sth->{1}->fetchrow_hashref;

    my $result = { id        => $sql_1_result->{user_manager_id},
                   password  => $sql_1_result->{password},
                   fullname  => $sql_1_result->{real_name},
                   privilege => $sql_1_result->{privilege} } || {};

    return $result;
}

sub _db_authen_fetch_user {

    my ($sub_hash) = @_;

    my $dbh = &_db_handle($db_auth_hash);
    my $sth = {};
    my $sql = {};

    my $result_hash = {};

    if($sub_hash->{username}){

        $sql->{1} = qq(select user_manager_id,username,password,real_name,privilege_to_user_manager_id as privilege from user_manager where username = ?);
        $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
        $sth->{1}->execute($sub_hash->{username}) or error("Error in sth_1 execute");
        my $sql_1_result = $sth->{1}->fetchrow_hashref;

        $result_hash = { id        => $sql_1_result->{user_manager_id},
                         password  => $sql_1_result->{password},
                         fullname  => $sql_1_result->{real_name},
                         privilege => $sql_1_result->{privilege} };
    }
    elsif($sub_hash->{id}){

        $sql->{1} = qq(select username,real_name from user_manager where user_manager_id = ?);
        $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
        $sth->{1}->execute($sub_hash->{id}) or error("Error in sth_1 execute");
        my $sql_1_result = $sth->{1}->fetchrow_hashref;

        $result_hash = { username  => $sql_1_result->{username},
                         fullname  => $sql_1_result->{real_name} };
    }
    else{

        $sql->{1} = qq(select user_manager_id as id,username as description from user_manager);
        $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
        $sth->{1}->execute() or error("Error in sth_1 execute");
        my $sql_1_result = $sth->{1}->fetchall_arrayref({});

        for my $row (@$sql_1_result){
            $result_hash->{ $row->{id} } = $row->{description};
        }
    }

    return $result_hash;
}

sub _db_change_password {

    my ($sub_hash) = @_;

    my $dbh = &_db_handle($db_auth_hash);
    my $sth = {};
    my $sql = {};

    my $sub_output = "Error changing password!";

    my $old_password = &_generate_password({ password => $sub_hash->{password} });

    my $new_password = &_generate_password({ password => $sub_hash->{npassword} });

    $sql->{1} = qq(select password from user_manager where username = ?);
    $sth->{1} = $dbh->prepare($sql->{1}) or error("Error in sth_1");
    $sth->{1}->execute($sub_hash->{username}) or error("Error in sth_1 execute");
    my $sql_1_result = $sth->{1}->fetchrow_hashref;

    if($sql_1_result->{password}){

        if($old_password eq $sql_1_result->{password}){

            $sql->{2} = qq(update user_manager set password = ? where username = ?);
            $sth->{2} = $dbh->prepare($sql->{2}) or error("Error in sth_2");
            $sth->{2}->execute($new_password, $sub_hash->{username}) or error("Error in sth_2 execute");
            $sth->{2}->finish;

            $sub_output = "Updated password successfully!";
        }
    }

    $sth->{1}->finish;
    $dbh->disconnect;

    return $sub_output;
}

true;
