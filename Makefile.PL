use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'MPE::IMAGE',
    'VERSION_FROM'	=> 'IMAGE.pm', # finds $VERSION
);

sub MY::postamble {
  '
lint: IMAGE.c
	lclint +gnuextensions +posixlib $(CCDFLAGS) -I$(PERL_INC) $(DEFINE) IMAGE.c
  ';
}
