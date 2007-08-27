use Test::Simple 'no_plan';
use lib './lib';
use CGI::Application::Gallery;
use Cwd;
use File::Path;

# setup
ok(1,'setup to test');
File::Path::rmtree( cwd().'/t/public_html');
File::Path::mkpath( cwd().'/t/public_html/gallery');



for (<public_html/gallery/*.jpg>){
	`cp "$_" ./t/public_html/gallery/`;
}
$ENV{DOCUMENT_ROOT} = cwd().'/t/public_html';
$ENV{CGI_APP_RETURN_ONLY} = 1;


# start
my $g;
ok($g = new CGI::Application::Gallery( 
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



ok( File::Path::rmtree( cwd().'/t/public_html'), 'cleanup');



