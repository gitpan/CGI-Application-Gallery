package CGI::Application::Gallery;
use strict;
use warnings;

use base 'CGI::Application';
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Forward;
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::Feedback ':all';
use Carp;
use Data::Page;
use File::PathInfo::Ext;
use File::Path;
use CGI::Application::Plugin::Stream 'stream_file';
use CGI::Application::Plugin::Thumbnail ':all';
use CGI::Application::Plugin::TmplInnerOuter;

use LEOCHARRE::DEBUG;
our $VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)/g;






sub setup {
	my $self = shift;
	$self->start_mode('browse');
	$self->mode_param('rm');
}

sub cgiapp_postrun {
	my $self = shift;
   
   debug("===== RUNMODE %s ==================\n", $self->get_current_runmode);
   return 1;     
}



=pod

=head1 NAME

CGI::Application::Gallery - image gallery module 

=head1 DESCRIPTION

I must have coded fifty different image gallery scripts in the last 10 years.
I think doing this in CGI::Application has staying power.

This is in development- but is fully usable. At this point, you will have to view/isnpect or use
the included browse.html and view.html HTML::Template files.

=head2 PROS

Uses cgi application, HTML::Template, etc. Uses a lot of code from stable, good packages.
Presentation is TOTALLY separated from back-end, and from content.
You can make this look like whatever you want, pixel precision art of minimal text layout.

Simple drop in, you create your hirerarchy of stuff, and the program takes care of the rest.

=head2 CONS

Uses cgi application, HTML::Template, etc. Uses a lot of code from stable, good packages.
Could be clunky- doesn't feel like it, but.. I know these packages have a lot of stuff utterly unused
here.
If you don't have root access, you will need to know how to use cpan command line.

=head1 RUNMODES

=cut

sub browse : Runmode {
	my $self = shift;

   $self->_set_tmpl_default(q{
	<TMPL_IF CURRENT_PAGE>
	<div>
	<p><TMPL_IF PREVIOUS_PAGE><a href="?rm=browse&current_page=<TMPL_VAR PREVIOUS_PAGE>">previous page</a> : </TMPL_IF>
	<TMPL_IF CURRENT_PAGE>Page <TMPL_VAR CURRENT_PAGE></TMPL_IF>
	<TMPL_IF NEXT_PAGE> : <a href="?rm=browse&current_page=<TMPL_VAR NEXT_PAGE>">next page</a></TMPL_IF>
	</p>
	<p>
	<a href="?entries_per_page=5">[5pp]</a> : 
	<a href="?entries_per_page=10">[10pp]</a> : 
	<a href="?entries_per_page=25">[25pp]</a> 
	</p>
	</div>
	</TMPL_IF>	
	
	<div>	
	<table cellspacing="0" cellpadding="4" width="100%">
	<tr>
	<TMPL_LOOP NAME="LS"> <td><a href="?rm=view&rel_path=<TMPL_VAR REL_PATH>"><img src="?rm=thumbnail&rel_path=<TMPL_VAR REL_PATH>"></a></td>
	<TMPL_IF CLOSEROW></tr>
	<tr>
	</TMPL_IF>
	</TMPL_LOOP>
	</tr></table>
	
	<div>
	<h5>Directories</h5>
	<ul>
	<TMPL_IF REL_BACK><li><a href="?rm=browse&rel_path=<TMPL_VAR REL_BACK>">Parent Directory</a></li></TMPL_IF>
	<TMPL_LOOP NAME="LSD">
	<li><a href="?rm=browse&rel_path=<TMPL_VAR REL_PATH>"><TMPL_VAR FILENAME></a></li>
	</TMPL_LOOP>
	</ul>
	</div>});


	
	my @entries = $self->pager->splice($self->lsfa);

	my $row = 3; my $cell=0;
	my $loop=[]; 
	for (@entries){
		my $abs_path = $_;
		
		$cell++;
		
		my $rel_path = $abs_path; $rel_path=~s/^$ENV{DOCUMENT_ROOT}//;
		my $filename = $rel_path; $filename=~s/^.*\///;
		
		my $data ={
			rel_path => $rel_path,
			filename => $filename,
		};	

		if ($cell == $row){
			$data->{closerow} = 1;
			$cell=0;
		}


		push @$loop, $data;
		
	}


	$row = 3; $cell=0;
	my $loopd=[]; 
	for (@{$self->cwr->lsda}){
		my $abs_path = $_;
		
		$cell++;
		
		my $rel_path = $abs_path; $rel_path=~s/^$ENV{DOCUMENT_ROOT}//;
		my $filename = $rel_path; $filename=~s/^.*\///;
		
		my $data ={
			rel_path => $rel_path,
			filename => $filename,
		};	

		if ($cell == $row){
			$data->{closerow} = 1;
			$cell=0;
		}

		push @$loopd, $data;
		
	}


	$self->_set_vars( 
      LS => $loop,
	   LSD => $loopd,
   );

	if ( $self->pager->last_page > 1 ) { # if we need paging.
   
		$self->_set_vars( 
         ENTRIES_PER_PAGE=> $self->pager->entries_per_page,
		   PREVIOUS_PAGE =>	$self->pager->previous_page,
         CURRENT_PAGE =>		$self->pager->current_page,
		   NEXT_PAGE =>			$self->pager->next_page,	
      );
      
	 #    debug( sprintf "perpage[%s] prev [%s] curr [%s] next[%s]\n", $self->pager->entries_per_page, $self->pager->previous_page, $self->pager->current_page, $self->pager->next_page );
	   $self->_debug_vars if DEBUG;		
	}	

	$self->_set_vars( rel_path => '/'.$self->cwr->rel_path );

	unless( $self->cwr->is_DOCUMENT_ROOT ){ # TODO this could be better, should lock into gallery space.. ??
		$self->_set_vars( rel_back => '/'.$self->cwr->rel_loc ); 
	
	}
	
	return $self->tmpl_output;
}



sub view : Runmode {
	my $self = shift;

   $self->_set_tmpl_default(q{
      <p><a href="<TMPL_VAR REL_BACK>">back</a></p>
      <h1><TMPL_VAR REL_PATH></h1>
      <p><img src="?rm=thumbnail&rel_path=<TMPL_VAR REL_PATH>&thumbnail_restriction=350x350"></p>
      <p><a href="<TMPL_VAR REL_PATH>">full view</p>      
   });  

	$self->_set_vars(
	   rel_path => '/'.$self->cwr->rel_path,
      rel_back => '?rm=browse&rel_path=/'.$self->cwr->rel_loc,
   );
   
	return $self->tmpl_output;
}

sub CGI::Application::Plugin::TmplInerOuter::tmpl_output {
   my $self = shift;
   $self->_set_tmpl_default(q{
   <html>
   <body>
   <div>
   <TMPL_LOOP FEEDBACK>
   <p><small><TMPL_VAR FEEDBACK></small</p>
   </TMPL_LOOP>
   </div>
   
   <div>
   <TMPL_VAR BODY>
   </div>
   </body>
   </html>},'main.html');

   
   $self->_set_vars( FEEDBACK => $self->get_feedback_prepped );
   
   $self->_feed_vars_all;
   $self->_feed_merge;
   return $self->_tmpl_outer->output;
}

=head1 LOOK AND FEEL

All templates are provided hard coded.
You can override the look and feel simply by creating templates on disk.
The are all L<HTML::Template> objects.
This is done via L<CGI::Appplication::Plugin::TmplInnerOuter>

=head2 OVERRIDING MAIN TEMPLATE

The main template is :

   <html>
   <body>
   <div>
   <TMPL_LOOP FEEDBACK>
   <p><small><TMPL_VAR FEEDBACK></small</p>
   </TMPL_LOOP>
   </div>
   
   <div>
   <TMPL_VAR BODY>
   </div>
   </body>
   </html>

If you create a main.html file with at least the template variable <TMPL_VAR BODY>, it will override the hard coded one 
shown above.

This may be enough for your customizing needs. 
If you want more read on..



=head2 OVERRIDING VIEW TEMPLATE

When you click to see medium view, the 'view' runmode.. the template you want to create will be called 'view.html'.

It shoudl contain something like:

 <p><a href="<TMPL_VAR REL_BACK>">back</a></p>
 <h1><TMPL_VAR REL_PATH></h1>
 <p><img src="?rm=thumbnail&rel_path=<TMPL_VAR REL_PATH>&thumbnail_restriction=350x350"></p>
 <p><a href="<TMPL_VAR REL_PATH>">full view</p> 

Shown above is default template.
Obviously the deafault is seen there as 350x350, if you want your view to be 500x500, just change the text in your
template. IT'S THAT EASY! Bless HTML::Template!!!!!!

You notice this template has no html header and footer.
That's beacuse it is inserted into the <TMPL_VAR BODY> tag of main.



=head2 OVERRIDING BROWSE TEMPLATE


This one is more complex. Simply create a browse.html template file and place this in it:

   <!-- begin pager -->
	<TMPL_IF CURRENT_PAGE>
	<div>
	<p><TMPL_IF PREVIOUS_PAGE><a href="?rm=browse&current_page=<TMPL_VAR PREVIOUS_PAGE>">previous page</a> : </TMPL_IF>
	<TMPL_IF CURRENT_PAGE>Page <TMPL_VAR CURRENT_PAGE></TMPL_IF>
	<TMPL_IF NEXT_PAGE> : <a href="?rm=browse&current_page=<TMPL_VAR NEXT_PAGE>">next page</a></TMPL_IF>
	</p>
	<p>
	<a href="?entries_per_page=5">[5pp]</a> : 
	<a href="?entries_per_page=10">[10pp]</a> : 
	<a href="?entries_per_page=25">[25pp]</a> 
	</p>
	</div>
	</TMPL_IF>	
   <!-- end pager -->
	

   <!--begin thumbnails -->
	<div>	
	<table cellspacing="0" cellpadding="4" width="100%">
	<tr>
	<TMPL_LOOP NAME="LS"> <td><a href="?rm=view&rel_path=<TMPL_VAR REL_PATH>"><img src="?rm=thumbnail&rel_path=<TMPL_VAR REL_PATH>"></a></td>
	<TMPL_IF CLOSEROW></tr>
	<tr>
	</TMPL_IF>
	</TMPL_LOOP>
	</tr></table>
   <!-- end thumbnails -->


   <!-- beign subdirs -->	
	<div>
	<h5>Directories</h5>
	<ul>
	<TMPL_IF REL_BACK><li><a href="?rm=browse&rel_path=<TMPL_VAR REL_BACK>">Parent Directory</a></li></TMPL_IF>
	<TMPL_LOOP NAME="LSD">
	<li><a href="?rm=browse&rel_path=<TMPL_VAR REL_PATH>"><TMPL_VAR FILENAME></a></li>
	</TMPL_LOOP>
	</ul>
	</div>
   <!-- end subdirs -->

=head2 WHERE SHOULD main.html view.html AND browse.html GO?

When you start your app:

   
   use CGI::Application::Gallery;

   my $g = new CGI::Application::Gallery( 
      TMPL_PATH => 'tmpl/',
   );
   $g->run;




=cut





sub error : Runmode {}




sub thumbnail : Runmode {
	my $self = shift; 
  
   $self->get_abs_image('rel_path') or return;      
   $self->abs_thumbnail or return;    
   $self->thumbnail_header_add;

   $self->stream_file( $self->abs_thumbnail ) or warn("thumbnail runmode: could not stream thumb ".$self->abs_thumbnail);
   return;
}

=head2 browse()

view gallery thumbs

=head2 view()

view a single image

=head2 thumbnail()

needs in query string= ?rm=thumbnail&rel_path=/gallery/1.jpg&restriction=40x40
Please see CGI::Application::Plugin::Thumbnail



=head1 METHODS

=head2 new()

 my $g = new CGI::Application::Gallery( 
	PARAMS => { 
		rel_path_default => '/',
		entries_per_page_min => 4,
		entries_per_page_max => 100,
		entries_per_page_default => 10,		
	},
 );

Shown are the default parameters.

=cut





sub cwr {
	my $self = shift;

	unless( defined $self->{cwr} and $self->{cwr} ){	

   
         $self->_cwr_from_query or          
         $self->_cwr_from_session or 
         $self->_cwr_from_default or
            confess('cant even set default gallery path');  

      if ($self->get_current_runmode eq 'browse' and $self->cwr->is_file){
          $self->_cwr_set_via_rel($self->cwr->rel_loc) or
            $self->_cwr_from_from_default or confess('cant set default');
      }

	}
	return $self->{cwr};
}


sub _cwr_from_query {
   my $self = shift;
   my $rel = $self->query->param('rel_path');
   defined $rel or return 0;

   $self->_cwr_set_via_rel($rel) or return;
   $self->session->param( '_rel_path' => $self->cwr->rel_path );      
   return 1;   
}

sub _cwr_from_session {
   my $self = shift;
   my $rel = $self->session->param('_rel_path');
   defined $rel or return;  
   $self->_cwr_set_via_rel($rel) and return 1;
   
   # failed.. clear session 
   $self->session->clear('_rel_path');
   return 0;   
}

sub _cwr_from_default {
	my $self = shift;
   my $rel = $self->param('rel_path_default'); 
   $rel ||= '/';
   
   $self->_cwr_set_via_rel($rel) or return 0;
   return 1;
}

sub _cwr_set_via_rel {
   my ($self, $rel) = @_; defined $rel or return;
   my $cwr = new File::PathInfo::Ext( $ENV{DOCUMENT_ROOT}.'/'. $rel ) or return 0;
   $self->{cwr} = $cwr;
   return 1;
   
}



=for later


sub _gallery_docroot {
   my $self = shift;
   if ( defined $self->param('rel_path_default') and $self->param('rel_path_default') ){
      return $ENV{DOCUMENT_ROOT}.'/'.$self->param('rel_path_default');
   }
   
   return $ENV{DOCUMENT_ROOT};
}

=cut


sub lsfa {
	my $self = shift;
	unless( $self->{lsfa} ){
		my @ls = grep { /[^\/]+\.jpe?g$|[^\/]+\.png$/i } @{$self->cwr->lsfa};
		$self->{lsfa} = \@ls;
	}
	return $self->{lsfa};
}

sub entries_total {
	my $self = shift;
	$self->{entries_total} ||= scalar @{$self->lsfa}; # dirs too???
	return $self->{entries_total};
}


sub pager {
	my $self = shift;
	$self->cwr->is_dir or croak('why call paging(), this is not a dir.');
	unless($self->{pager}){
	
		$self->{pager} = new Data::Page( $self->entries_total, $self->_entries_per_page, $self->_current_page );	

		if ($self->_current_page > $self->{pager}->last_page){
			$self->{pager}->current_page($self->{pager}->last_page);
		} 
		$self->session->param( current_page => $self->{pager}->current_page );
		
	}
	return $self->{pager};
}

sub _entries_per_page {
	my $self = shift;

#	unless( $self->{entries_per_page} ){
	
		$self->param('entries_per_page_default') or $self->param('entries_per_page_default', 10); # optionally set via constructor	
		$self->param('entries_per_page_max') or $self->param('entries_per_page_max', 100); # optionally set via constructor
		$self->param('entries_per_page_min') or $self->param('entries_per_page_min', 4); # optionally set via constructor
	
		my $perpage;
		
		if ( $self->query->param('entries_per_page') ){
			$perpage = $self->query->param('entries_per_page');
		}
		elsif ( $self->session->param('entries_per_page') ){
			$perpage = $self->session->param('entries_per_page');
		}
		else {
			$perpage = $self->param('entries_per_page_default');
		}
	
		$perpage=~/^\d+$/ or $perpage = $self->{entries_per_page_default}; 
		$perpage <= $self->param('entries_per_page_max') or $perpage = $self->param('entries_per_page_max');
		$perpage >= $self->param('entries_per_page_min') or $perpage = $self->param('entries_per_page_min');
			
		$self->session->param( entries_per_page => $perpage ); 
		
		$self->{entries_per_page} = $perpage;
#	}
	return $self->{entries_per_page};
}

sub _current_page { # ?
	my $self = shift;

#	unless( $self->{current_page} ){
		
		my $page;	
		
		if ( $self->query->param('current_page') ){
			$page = $self->query->param('current_page');
		}
		elsif ( $self->session->param('current_page') ){
			$page = $self->session->param('current_page');
		}
		else {
			$page = 1;
		}
		
		$page=~/^\d+$/ or $page = 1;
		$page ||= 1;
		
		# set the page in the pager????
		$self->{current_page} = $page;
#	}
	return $self->{current_page};
}


=head2 entries_total()

=head2 entries_per_page()

=head2 current_page()

=head2 pager()

returns Data::Page object

=head2 lsfa()

returns abs paths of only image files in current dir

=head1 PREREQUISITES

CGI::Application
CGI::Application::Plugin::Session
CGI::Application::Plugin::Forward
CGI::Application::Plugin::AutoRunmode
CGI::Application::Plugin::Feedback
CGI::Application::Plugin::Stream
CGI::Application::Plugin::Thumbnail
CGI::Application::Plugin::TmplInnerOuter
File::PathInfo::Ext
Data::Page
File::Path
Smart::Comments
Carp

=head1 BUGS

Yes. Please email author.

=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=cut


1;
