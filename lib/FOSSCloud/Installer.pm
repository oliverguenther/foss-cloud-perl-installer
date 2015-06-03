package FOSSCloud::Installer;

use Config::Merge;
use Module::Load;
use File::Basename qw(basename);
use File::Spec qw(catdir);
use Modern::Perl;
use utf8;

# ABSTRACT: Perl-based FOSS-Cloud Installer

sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

	$self->{params} = $params;
	Config::Merge->import('FOSSCloud::Installer::Config' => $$params{config});

	return $self;
}

sub run {
	my $self = shift;

	my @steps = qw(
		CheckCPU
		CheckMemory
	    CheckSelectedDevice
	    LVMCleanup
	    DevicePartitioning
	    LVMSetup
	    UnpackStage4Tarball
	    SetNodeType
	    FstabCreation
	    NetworkConfiguration
	    BootLoaderInstallation
	    FinishMessage
	);

	for my $s (@steps) {
		my $module = "FOSSCloud::Installer::Steps::$s";
		load $module;
		$module->new($self->{params});
	}
	
}

1;