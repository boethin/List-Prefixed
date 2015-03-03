use 5.014002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	NAME              => 'List::Prefixed',
	VERSION_FROM      => 'lib/List/Prefixed.pm', # finds $VERSION
	ABSTRACT_FROM  => 'lib/List/Prefixed.pm', # retrieve abstract from module
	PREREQ_PM         => {}, # e.g., Module::Name => 1.1
	AUTHOR         => 'Sebastian Böthinr <boethin@xn--domain.net>',
);

sub MY::postamble {
	return <<'EOF';
# 'make readme'
# generate README.* from pod section
.PHONY: readme
readme: README README.pod README.md
README README.pod README.md: $(VERSION_FROM)

README:
	pod2text $< >$@

README.pod:
	podselect $< >$@

README.md:
	pod2markdown $< >$@
	
EOF
}


