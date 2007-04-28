#!/usr/bin/perl -w
use lib './lib';
use lib '../lib';
use CGI::Application::Gallery;

my $g = new CGI::Application::Gallery( 
	PARAMS => { rel_path_default => '/gallery' },
);
$g->run;


