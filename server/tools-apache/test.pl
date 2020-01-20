#!/usr/bin/perl
use coresubs qw(print_header pre next_date print_template);
use send_mes;
use freshdb;
use strict;
use lib '/var/www/lib';
use odt_file2;

our $db=freshdb->new(connect_name=>'strateg_read');
print_header();
pre($db);
