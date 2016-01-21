#!/usr/bin/perl

# http://perlmaven.com/getting-started-with-perl-dancer-on-digital-ocean

use warnings;
use strict;
use Daemon::Control;
 
use Cwd qw(abs_path);
 
Daemon::Control->new(
    {
        name      => "StuffTracker",
        lsb_start => '$syslog $remote_fs',
        lsb_stop  => '$syslog',
        lsb_sdesc => 'StuffTracker',
        lsb_desc  => 'StuffTracker',
        path      => abs_path($0),
 
        program      => '/usr/bin/starman',
        program_args => [ '--workers', '3', '--port', '5000', '/home/starman/StuffTracker/bin/app.psgi' ],
 
        user  => 'starman',
        group => 'starman',
 
        pid_file    => '/tmp/StuffTracker.pid',
        stderr_file => '/tmp/StuffTracker.err',
        stdout_file => '/tmp/StuffTracker.out',
 
        fork => 2,
    }
)->run;
