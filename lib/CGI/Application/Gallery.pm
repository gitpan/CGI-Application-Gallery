package CGI::Application::Gallery;
use base 'CGI::Application';
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::Forward;
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::Feedback ':all';
use strict;
use Carp;
use Data::Page;
use File::PathInfo::Ext;
use File::Path;
use warnings;
use CGI::Application::Plugin::Stream 'stream_file';
use Image::Magick::Thumbnail;
use Smart::Comments '###';
our $VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)/g;
my $DEBUG = 1;
sub DEBUG : lvalue { $DEBUG }

sub setup {
	my $self = shift;
	$self->start_mode('browse');
	$self->mode_param('rm');
	

}

sub cgiapp_postrun {
	my $self = shift;
	(printf STDERR "===== RM %s ==================\n", $self->get_current_runmode) if DEBUG;
}


=head1 RUNMODES

=cut

sub browse : Runmode {
	my $self = shift;

	
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


	$self->tmpl->param( LS => $loop );
	$self->tmpl->param( LSD => $loopd);

	if ( $self->pager->last_page > 1 ) { # if we need paging.
		$self->tmpl->param( ENTRIES_PER_PAGE=> $self->pager->entries_per_page );	
		$self->tmpl->param( PREVIOUS_PAGE =>	$self->pager->previous_page );
		$self->tmpl->param( CURRENT_PAGE =>		$self->pager->current_page );
		$self->tmpl->param( NEXT_PAGE =>			$self->pager->next_page );	
		if (DEBUG){
			printf STDERR "perpage[%s] prev [%s] curr [%s] next[%s]\n", 
				$self->pager->entries_per_page, $self->pager->previous_page, $self->pager->current_page, $self->pager->next_page ;
		}	
	}	

	$self->tmpl->param( rel_path => '/'.$self->cwr->rel_path );

	unless( $self->cwr->is_DOCUMENT_ROOT ){ # TODO this could be better, should lock into gallery space.. ??
		$self->tmpl->param( rel_back => '/'.$self->cwr->rel_loc ); 
	
	}
	
	return $self->tmpl->output;
}


sub view : Runmode {
	my $self = shift;

	$self->tmpl->param( rel_medium => '?rm=medium&rel_path=/'.$self->cwr->rel_path ); # if they want to use it.
	$self->tmpl->param( rel_path => '/'.$self->cwr->rel_path );
	$self->tmpl->param( rel_back =>'?rm=browse&rel_path=/'.$self->cwr->rel_loc ); 
	
	return $self->tmpl->output;
}

sub error : Runmode {}



sub medium : Runmode {
	my $self = shift;

	# setup
	$self->param('rel_path_medium') or $self->param('rel_path_medium', '/.medium'); 	
	$self->param('medium_restriction') or $self->param('medium_restriction', '400x400');


	# is there a path to what image?
	$self->query->param('rel_path') or 
		carp "medium runmode: no rel path" and return;


	# the image we want thumb for
	my $abs_original = $ENV{DOCUMENT_ROOT}.'/'.$self->query->param('rel_path');
	
	
	# is that image there?	
   -f $abs_original 
      or carp "medium runmode: image [$abs_original] is not there, cant make medium" 
      and return;
	
	
	# where do we store thumbnails?
   my $abs_mediums = $ENV{DOCUMENT_ROOT}.'/'.$self->param('rel_path_medium');	
	   	
			
	# where should the thumbnail be?
   my $abs_medium = "$abs_mediums/$abs_original"; 
	
	
	# if the thumbnail is not there, make it.
   unless( -f $abs_medium){

		-d $abs_mediums or mkdir $abs_mediums or die("thumbnail runmode: can't mkdir[$abs_mediums], $!");
	
      my $abs_medium_loc = $abs_medium; # absolute thumbnail location
      $abs_medium_loc=~s/\/[^\/]+$// or die("thumbnail runmode: regex problem with [$abs_medium_loc]");

      -d $abs_medium_loc
         or File::Path::mkpath($abs_medium_loc) 
         or die("medium runmode: cant make destination dir for thumb [$abs_medium_loc]");
      
      # make thumb
      my $img = new Image::Magick;
      $img->Read($abs_original);
      my ($thumb,$x,$y) = Image::Magick::Thumbnail::create($img,$self->param('medium_restriction'));
		$thumb->Set(compression => '8'); # ?????
      $thumb->Write($abs_medium);
   }   


	# ok, send it   
   $self->stream_file( $abs_medium )
      or carp "medium runmode: could not stream medium [$abs_medium]";
   return;
}


sub thumbnail : Runmode {
	my $self = shift;

	# setup
	$self->param('rel_path_thumbnails') or $self->param('rel_path_thumbnails', '/.thumbnails'); 	
	$self->param('thumbnails_restriction') or $self->param('thumbnails_restriction', '100x100');


	# is there a path to what image?
	$self->query->param('rel_path') or 
		carp "thumbnail runmode: no rel path" and return;


	# the image we want thumb for
	my $abs_original = $ENV{DOCUMENT_ROOT}.'/'.$self->query->param('rel_path');
	
	
	# is that image there?	
   -f $abs_original 
      or carp "thumbnail runmode: image [$abs_original] is not there, cant make thumb" 
      and return;
	
	
	# where do we store thumbnails?
   my $abs_thumbs = $ENV{DOCUMENT_ROOT}.'/'.$self->param('rel_path_thumbnails');	
	   	
			
	# where should the thumbnail be?
   my $abs_thumb = "$abs_thumbs/$abs_original"; 
	
	
	# if the thumbnail is not there, make it.
   unless( -f $abs_thumb){

		-d $abs_thumbs or mkdir $abs_thumbs or die("thumbnail runmode: can't mkdir[$abs_thumbs], $!");
	
      my $abs_thumb_loc = $abs_thumb; # absolute thumbnail location
      $abs_thumb_loc=~s/\/[^\/]+$// or die("thumbnail runmode: regex problem with [$abs_thumb_loc]");

      -d $abs_thumb_loc
         or File::Path::mkpath($abs_thumb_loc) 
         or die("thumbnail runmode: cant make destination dir for thumb [$abs_thumb_loc]");
      
      # make thumb
      my $img = new Image::Magick;
      $img->Read($abs_original);
      my ($thumb,$x,$y) = Image::Magick::Thumbnail::create($img,$self->param('thumbnails_restriction'));
		$thumb->Quantize(colorspace => 'gray'); # ???????
		$thumb->Set(compression => '8');
      $thumb->Write($abs_thumb);
   }   


	# ok, send it   
   $self->stream_file( $abs_thumb )
      or carp "thumbnail runmode: could not stream thumb [$abs_thumb]";
   return;
}

=head2 browse()

view gallery thumbs

=head2 view()

view a single image

=head2 thumbnail()

needs in query string= ?rm=thumbnail&rel_path=/gallery/1.jpg&restriction=40x40


=head1 METHODS


=head2 new()


 my $g = new CGI::Application::Gallery( 
	PARAMS => { 
		rel_path_default => '/',
		rel_path_thumbnails => '/.thumbnails',
		thumbnails_restriction => '100x100',
		entries_per_page_min => 4,
		entries_per_page_max => 100,
		entries_per_page_default => 10,
	}
 );

Shown are the default parameters.


			
=cut

sub tmpl {
	my $self = shift;
	unless ( defined $self->{tmpl} ){

		my $tmpl = $self->load_tmpl(undef, die_on_bad_params => 0 );
		$self->{tmpl} = $tmpl;

		#my $vars = {		
		#};

		#for( keys %$vars){ 
	#		print STDERR __PACKAGE__."::tmpl() $_ : $$vars{$_}\n" if DEBUG;
#			$self->{tmpl}->param( $_ => $vars->{$_} ); 		
#		}
		
	}
	return $self->{tmpl};
}

sub cwr {
	my $self = shift;

	unless( $self->{cwr} ){	


		$self->param('rel_path_default') 
			or $self->param('rel_path_default', '/'); # optionally set via constructor		
	
		# user choice present ?
		if ( $self->query->param('rel_path') ){			
			 
			if (!$self->query->param('rel_path')) { # was user choice nothing? then clear it
				$self->session->clear('_rel_path');
			}
			
			else { # save choice in session
				$self->session->param( _rel_path => $self->query->param('rel_path') );
			}		
		}
		
		unless( $self->session->param('_rel_path') ){ # if nothing in session, set default
			$self->session->param('_rel_path' => $self->param('rel_path_default') );	
		}		


		# now attempt to set the path
		if ( my $cwr = new File::PathInfo::Ext( $ENV{DOCUMENT_ROOT}.'/'. $self->session->param('_rel_path')) ){
			$self->{cwr} = $cwr;			
		}
		else {
			$self->feedback("Sorry, cannot view [". $self->session->param('_rel_path')."], this resource is not presently available.");
			$self->{cwr} = _default($self);
		}		

	}
	return $self->{cwr};

	sub _default {
		my $self = shift;
		my $cwr = new File::PathInfo::Ext( $ENV{DOCUMENT_ROOT} .'/'.$self->param('rel_path_default') ) 
			or croak("cannot set default rel path ".$self->param('rel_path_default') );
		return $cwr;
	}
}

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



=head1 AUTHOR

Leo Charre leocharre at cpan dot org

=cut


1;
