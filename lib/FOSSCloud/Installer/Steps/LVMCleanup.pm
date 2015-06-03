package FOSSCloud::Installer::Steps::LVMCleanup;

use FOSSCloud::Installer::Config;
use FOSSCloud::Installer::Common::LVM;
use Modern::Perl;
use IPC::Run qw(run);
use String::Util 'trim';
use File::Path qw(make_path);
use feature 'switch';
use utf8;

=head1 FOSSCloud::Installer::Steps::LVMCleanup

Remove earlier FOSS Logical Volumes

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    # header "Logical Volume Cleanup and Preparation"
    # info "Checking for existing volume groups and physical volumes"

    # Set a liberal LVM device filter to get all existing physical volumes
    my $liberal_filter ='/dev/(s|h)d[a-z][0-9]*';
    FOSSCloud::Installer::Common::LVM::update_filter_string($liberal_filter);

    die "Unable to scan the LVM volume groups"
    unless system('vgscan > /dev/null') == 0;


    # Getting existing related physical volumes, in order to deal with leftovers
    # from a previously (faild) installation
    # debug "Getting existing ${osbdProjectName} related LVM physical volumes"
    for my $vg (C('defaults.osbdLvmVolumeGroup0'), C('defaults.osbdLvmVolumeGroup1')) {
        # debug "Search for physical volumes related to volume group ${vg}"
        my $pvs = $self->find_pvs_volume($vg);

        if (!$pvs) {
            # debug "No PVs found which belong to '${vg}'"
            next;
        }

        say "Found existing " . C('defaults.projectname') . " related physical volumes for";
        say "volume group ${vg}:";
        say "${pvs}";
        say "";
        say "Those are most likely leftovers from a previous installation";
        say "In order to continue those volume groups and physical volumes";
        say "have to be removed";
        say "THIS MEANS THAT ALL LVM META DATA WILL BE LOST";

        die "Cowardly refusing to delete volume groups until forced to do so\nUse `--lvm-cleanup` to force this deletion."
        unless ($params->{'lvm-cleanup'});

        # Unmount vgs
        system("umount /dev/$vg/* >/dev/null 2>&1");

        # deactivate all existing volume groups
        die "Unable to deactivate the LVM volume group '$vg'"
        unless system("vgchange -a n $vg > /dev/null") == 0;

        # remove volume group
        die "Unable to remove the LVM volume group"
        unless system("vgremove --force $vg") == 0;

        # remove all pvs
        # debug "Wiping LVM label on ${pv}"

        die "Unable to wipe the LVM label on device '$pvs'"
        unless system("pvremove --force $pvs") == 0;
    }

    # Unmount all partitions
    my $target_device = C('system.target_device');
    system("umount /dev/${target_device}* >/dev/null 2>&1");

}

sub find_pvs_volume {
    my ($self, $vg) = @_;

    my $sep = ':';
    my $regex= "${sep}${vg}"; # ex.: :my_vg$

    my $out;
    run ['pvs', '--noheadings', '--options=pv_name,vg_name', "--separator=${sep}"],
        '|',
        ['grep', '-E', $regex],
        '|',
        ['cut', "--delimiter=$sep", '--field=1'],
        '|',
        ['cut', '--characters=3-'],
        \$out;

    return trim($out);
}


1;
