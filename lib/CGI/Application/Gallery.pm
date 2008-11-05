package CGI::Application::Gallery;
use strict;
use warnings;
use base 'CGI::Application';
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Forward;
use CGI::Application::Plugin::Feedback ':all';
use Carp;
use Data::Page;
use File::PathInfo::Ext;
use File::Path;
use CGI::Application::Plugin::Stream 'stream_file';
use CGI::Application::Plugin::Thumbnail ':all';
#use CGI::Application::Plugin::TmplInnerOuter;
use HTML::Template::Default 'get_tmpl';

use LEOCHARRE::DEBUG;
our $VERSION = sprintf "%d.%02d", q$Revision: 1.8 $ =~ /(\d+)/g;


sub setup {
	my $self = shift;
	$self->start_mode('browse');
   $self->run_modes([qw(browse view thumbnail download view_full)]);
}


sub cgiapp_postrun {
	my $self = shift;   
   printf STDERR "===== RUNMODE %s ==================\n", $self->get_current_runmode;
   return 1;     
}


sub browse { # runmode
	my $self = shift;
   if ($self->cwr->is_file){ 
      return $self->forward('view');
   }

   my $default = q{
	<TMPL_IF CURRENT_PAGE>
	<div>
	<p><TMPL_IF PREVIOUS_PAGE><a href="?current_page=<TMPL_VAR PREVIOUS_PAGE>">previous page</a> : </TMPL_IF>
	<TMPL_IF CURRENT_PAGE>Page <TMPL_VAR CURRENT_PAGE></TMPL_IF>
	<TMPL_IF NEXT_PAGE> : <a href="?current_page=<TMPL_VAR NEXT_PAGE>">next page</a></TMPL_IF>
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
	<TMPL_LOOP NAME="LS"> <td><a href="?rel_path=<TMPL_VAR REL_PATH>"><img src="?rm=thumbnail&rel_path=<TMPL_VAR REL_PATH>"></a></td>
	<TMPL_IF CLOSEROW></tr>
	<tr>
	</TMPL_IF>
	</TMPL_LOOP>
	</tr></table>
	
	<div>
	<h5>Directories</h5>
	<ul>
	<TMPL_IF REL_BACK><li><a href="?rel_path=<TMPL_VAR REL_BACK>">Parent Directory</a></li></TMPL_IF>
	<TMPL_LOOP NAME="LSD">
	<li><a href="?rel_path=<TMPL_VAR REL_PATH>"><TMPL_VAR FILENAME></a></li>
	</TMPL_LOOP>
	</ul>
	</div>};
   
   my $tmpl = get_tmpl('browse.html',\$default);


	$tmpl->param( 
      rel_path => $self->cwr->rel_path,
      rel_back => $self->_rel_back,
      LS       => $self->_files_loop,
      LSD      => $self->_dirs_loop,
   );

   if( my $pp = $self->_pager_params ){
      $tmpl->param(%$pp);
   }

   my $t = $self->tmpl_outer;
   $t->param( BODY => $tmpl->output );   
	return $t->output;
}

sub _pager_params {
   my $self = shift;

	if ( $self->pager->last_page > 1 ) { # if we need paging.   
		return {
         ENTRIES_PER_PAGE  => $self->pager->entries_per_page,
		   PREVIOUS_PAGE     =>	$self->pager->previous_page,
         CURRENT_PAGE      =>	$self->pager->current_page,
		   NEXT_PAGE         =>	$self->pager->next_page,	
      };      
	}	
   return;
}

# show parent link or not, return 0 if not
sub _rel_back {
   my $self = shift;
   $self->_show_parent_link or return 0;
   return '/'.$self->cwr->rel_loc ; 	
}

sub _files_loop {
   my $self = shift;

   $self->cwr->lsf_count or return [];
	my @files_all  = grep { !/^\.|\/\./g } @{ $self->cwr->lsf } or return [];
      
   my $count = scalar @files_all;
   debug("files all $count");

   my @files = $self->pager->splice( \@files_all ) or die;   
   my $loop = $self->_ls_tmpl_loop(\@files) or die;

   return $loop;
}

sub _dirs_loop {
   my $self = shift;
   $self->cwr->lsd_count or return [];

   my @dirs = grep { !/^\.|\/\./g } @{$self->cwr->lsd};
   @dirs and scalar @dirs or return [];

   my $loop = $self->_ls_tmpl_loop( \@dirs);
   return $loop;
}


sub _ls_tmpl_loop {
   my( $self, $ls ) = @_;   
   ref $ls eq 'ARRAY' or confess;

   my $base_rel_path = $self->cwr->rel_path;
   debug("base rel path '$base_rel_path'");
   

   my @loop = ();

	my $row = 3; # per row
   my $cell= 0;

	LS: for my $filename (@$ls){

      $cell++;

		my $rel_path = $base_rel_path ."/$filename";
		
      my $closerow = 0;
		if ( $cell == $row ){
         $cell     = 0;
         $closerow = 1;
      }
		
		push @loop, {
         rel_path => $rel_path,
         filename => $filename,
         closerow => $closerow,
      };
	}
   return \@loop;
}





sub thumbnail { # runmode
	my $self = shift; 

   my $rel = $self->query->param('rel_path')
      or debug('no rel')
      and return;

   $self->set_abs_image( $self->abs_document_root.'/'.$rel );
  
   #$self->get_abs_image('rel_path') or return;      
   $self->abs_thumbnail or return;    
   $self->thumbnail_header_add;

   $self->stream_file( $self->abs_thumbnail ) 
      or warn("thumbnail runmode: could not stream thumb ".$self->abs_thumbnail);
   #return 1;
}






sub view { # runmode
	my $self = shift;
   if ($self->cwr->is_dir){ 
      return $self->forward('browse');
   }

   my $default = q{
      <p><a href="?rm=browse&rel_path=<TMPL_VAR REL_BACK>">back</a></p>
      <h1><TMPL_VAR REL_PATH></h1>
      <p><img src="?rm=thumbnail&rel_path=<TMPL_VAR REL_PATH>&thumbnail_restriction=350x350"></p>
      <p><a href="?rm=view_full">full size</a> | <a href="?rm=view_full">download</a></p>
   };  

   my $tmpl = get_tmpl('view.html',\$default);

	$tmpl->param(
	   rel_path => '/'.$self->cwr->rel_path,
      rel_back => $self->_rel_back,
   );

   my $t = $self->tmpl_outer;
   $t->param( BODY => $tmpl->output );   
	return $t->output;
}



sub view_full { # runmode
	my $self = shift;
   if ($self->cwr->is_dir){ 
      return $self->forward('browse');
   }

   my $default = q{<a href="<TMPL_VAR REL_BACK>" title="back"><img src="?rm=download"></a>};  

   my $tmpl = get_tmpl('view.html',\$default);

	$tmpl->param(
	   rel_path => '/'.$self->cwr->rel_path,
      rel_back => '?rm=view',
   );

   my $t = $self->tmpl_outer;
   $t->param( BODY => $tmpl->output );   
	return $t->output;
}



sub download {
   my $self = shift;
   
   my $abs_path = $self->session->param('abs_path')
      or die('no file chosen');
   
   -f $abs_path or die('not file');

   my $filename = $abs_path;
   $filename=~s/^.+\/+//;

   require File::Type;
   my $m = File::Type->new;
   my $mime = $m->mime_type($abs_path);

   $self->header_add(
      '-type' => $mime,
      '-attachment' => $filename
    );
  
   if ( $self->stream_file( $abs_path ) ){
      return
   }
   die("could not stream file ".$abs_path);
}


# support subs



sub tmpl_outer {
   my $self = shift;

   my $default = q{
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
   </html>};

   my $tmpl = get_tmpl('main.html',\$default);
   
   $tmpl->param( FEEDBACK => $self->get_feedback_prepped );
   return $tmpl;
}




sub _show_parent_link {
   my $self = shift;
   return ( $self->cwr->is_DOCUMENT_ROOT ? 0 : 1 );
}





sub cwr {
	my $self = shift;

	unless( $self->{cwr} ){
      my $abs = $self->abs_path;

      my $f = File::PathInfo::Ext->new( $abs );
      unless( $f ){
         $self->session->delete;
         die("not on disk $abs");
      }
      $f->DOCUMENT_ROOT_set($self->abs_document_root);
      $self->{cwr} = $f;
   }
         
	return $self->{cwr};
}
sub abs_path {
   my $self = shift;
   
   my $abs;

   # regardless, we want it in the session
   if( $abs = $self->_abs_from_query ){
      # to session
      $self->session->param(abs_path => $abs);
   }
   else { 
      $abs = $self->_abs_from_session;
   }
   return $abs;
}
sub _abs_from_query {
   my $self = shift;
   my $rel = $self->query->param('rel_path');
   defined $rel or debug('nothing in rel_path') and return;
   debug('got rel from q');
   if ( defined $rel and $rel eq ''  ){ # if def by empty string.. reset
      debug('empty string');
         return $self->abs_document_root;
   }
   debug("had $rel");
   return Cwd::abs_path( $self->abs_document_root . '/'. $rel ); # TODO make sure this is within docroot
}
sub _abs_from_session {
   my $self = shift;
   $self->session->param('abs_path') 
      or $self->session->param( 'abs_path' => $self->abs_document_root );
      debug('session.. '.$self->session->param('abs_path'));
   return $self->session->param('abs_path');
}







*_abs_path_default = \&abs_document_root;
sub abs_document_root {
   my $self = shift;
   unless( $self->{abs_document_root_resolved} ){
      my $a = $self->param( 'abs_document_root' ) or croak('missing abs_document_root param to constructor');
      require Cwd;
      my $r = Cwd::abs_path($a) or die("can't resolve '$a' to path");
      $self->{abs_document_root_resolved} = $r;
   }
   return $self->{abs_document_root_resolved};
}

sub _rel_path_default {
   return '/';
}




# PAGER

sub pager {
	my $self = shift;
	$self->cwr->is_dir or croak('why call paging(), this is not a dir.');
	unless($self->{pager}){
	
		$self->{pager} = new Data::Page(

         $self->cwr->lsf_count, 
         $self->user_pref( entries_per_page => 10 ), 
         $self->user_pref( current_page => 1 )
      );			
	}
	return $self->{pager};
}

sub user_pref {
   my ( $self, $param_name, $default ) = @_;
   
   my $val = $self->query->param($param_name);
   if( defined $val and $val eq '' ){
      $self->session->param( $param_name => $default );
   }
   
   elsif( $val ){
      $self->session->param( $param_name => $val );
   }

   return $self->session->param($param_name);
}

   

   


1;

__END__



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




=for later
sub _gallery_docroot {
   my $self = shift;
   if ( defined $self->param('rel_path_default') and $self->param('rel_path_default') ){
      return $ENV{DOCUMENT_ROOT}.'/'.$self->param('rel_path_default');
   }
   
   return $ENV{DOCUMENT_ROOT};
}
=cut


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

