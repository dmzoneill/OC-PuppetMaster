<?php

$host = isset( $_GET[ 'q' ] ) ? $_GET[ 'q'] : false;

if( $host == false )
{
    print 1;
    exit;
}

$dbgroup = ( preg_match( '/^silvubuntu00/' , $host , $matches ) == 1 ) ? "group1" : "none"; 
$dbmaster = ( $dbgroup == "group1" ) ? "silvubuntu001" : "none";
$dbslaves = ( $dbgroup == "group1" ) ? "silvubuntu002" : "none";

$webhost = ( preg_match( '/^silvubuntu002/' , $host , $matches ) == 1 ) ? "true" : "false"; 

print "
OC_dbgroup=$dbgroup
OC_dbmaster=$dbmaster
OC_dbslaves=$dbslaves
OC_webserver=$webhost
";
