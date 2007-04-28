use ExtUtils::MakeMaker;
WriteMakefile(
	NAME => 'CGI::Application::Gallery',
	VERSION_FROM => 'lib/CGI/Application/Gallery.pm',
	PREREQ_PM => {
		'CGI::Application' => 0,
		'CGI::Application::Plugin::Session' => 0,
		'CGI::Application::Plugin::Feedback' => 0,		
		'CGI::Application::Plugin::Session' => 0,
		'CGI::Application::Plugin::AutoRunmode' => 0,
		'CGI::Application::Plugin::Forward' => 0,
                'CGI::Application::Plugin::Stream' => 0,
		'Data::Page' => 0,
		'Carp' => 0,
		'File::PathInfo::Ext' => '1',
		'Image::Magick::Thumbnail' => 0,
	
	},

);
