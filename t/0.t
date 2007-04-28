use Test::Simple 'no_plan';
use lib './lib';
use CGI::Application::Gallery;
use Cwd;
use File::Path;

# setup

File::Path::rmtree( cwd().'/t/cgi-bin');
File::Path::rmtree( cwd().'/t/public_html');
File::Path::mkpath( cwd().'/t/public_html/gallery');
mkdir cwd().'/t/cgi-bin';
for (<cgi-bin/*.html>){
        `cp "$_" ./t/cgi-bin/`;
}



for (<public_html/gallery/*.jpg>){
	`cp "$_" ./t/public_html/gallery/`;
}
$ENV{DOCUMENT_ROOT} = cwd().'/t/public_html';



# start
my $g;
ok($g = new CGI::Application::Gallery( 
	TMPL_PATH => cwd().'/t/cgi-bin', 
	PARAMS => { 
		rel_path_default => '/gallery',
	},
),'instanced');

ok( $g->run,'run');

my $cwr;
ok( $cwr = $g->cwr,'got cwr' );

printf STDERR " # cwr abs path returns [%s]\n",$cwr->abs_path;

ok($cwr->abs_path eq cwd().'/t/public_html/gallery','cwd abs path is gallery');

ok($g->entries_total == 10,'entries_total() is 10');


printf STDERR " # current page is [%s]\n", $g->pager->current_page;

ok($g->pager->current_page == 1, 'current_page is 1');

