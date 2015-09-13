package FOSSCloud::Installer::Steps::LVMSetup;

use FOSSCloud::Installer::Config;
use FOSSCloud::Installer::Common::LVM;
use Modern::Perl;
use File::Spec;
use IPC::Run qw(run);
use File::Path qw(make_path);
use feature 'switch';
use utf8;

=head1 FOSSCloud::Installer::Steps::LVMSetup

FOSS Logical Volume Setup

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    # Set device path
    $self->{target_device_path} = '/dev/' . C('system.target_device');
    $self->{volume_group_0} = C('defaults.osbdLvmVolumeGroup0');
    $self->{volume_group_1} = C('defaults.osbdLvmVolumeGroup1');

    # Save LVM filter
    $self->set_lvm_filter;

    die "Error scanning LVM volume groups"
    unless system('vgscan') == 0;


    # Setup target volume
    $self->volume_setup($self->{pv0}, C('defaults.osbdLvmVolumeGroup0'));

    # Setup volumes in LVM target group
    $self->os_setup($self->{volume_group_0});

    # Setup data volume
    if (C('system.nodetype') eq 'storage') {

        # By default, use target vg
        my $data_group = C('defaults.osbdLvmVolumeGroup0');

        # Setup (separated) data volume
        if (defined $self->{pv1}) {
            $data_group = C('defaults.osbdLvmVolumeGroup1');
            $self->volume_setup($self->{pv1}, $data_group);
        }

        $self->create_volume_with_extents(
            "100%FREE",
            C('defaults.osbdGlusterVolumeName'),
            $data_group
        );
    }

    # Setup filesystem
    $self->setup_filesystem;

}

=head2 set_lvm_filter

Sets the LVM filter to the selected target,data
devices.

=cut
sub set_lvm_filter {
    my ($self) = @_;

    my $pv0 = $self->{pv0} = '/dev/' . C('system.target_device') . "5";

    my $lvm_filter = $self->{pv0};
    if (defined C('system')->{data_device}) {
        my $pv1 = $self->{pv1} = '/dev/' . C('system.data_device');
        $lvm_filter = "$pv0|$pv1";
    }

    FOSSCloud::Installer::Common::LVM::update_filter_string($lvm_filter);
}

=head2 volume_setup

Setup LVM volume.

Parameters:

    $path: Device path

    $group: Group identifier

=cut
sub volume_setup {
    my ($self, $path, $group) = @_;

    # debug "Creating physical volume on $path"

    die "Unable to create the LVM physical volume '$path'"
    if system("pvcreate -ff --zero y --yes $path") != 0;

    die "Unable to create the LVM volume group '$group'"
    if system("vgcreate $group $path") != 0;


}

=head2 os_setup

Setup LVM mounts on the target VG.

=cut
sub os_setup {
    my ($self, $group) = @_;

    my $volumes = C('system.volumes');
    while (my ($name, $volume) = each(%$volumes)) {

        next unless ($volume->{lvm});

        say "Creating volume '$name' with '$$volume{lvm_size}' under '$group'";
        $self->create_volume($group, $name, $volume->{lvm_size});
    }

    # TODO
    # Demo-Systems and Single-Server installations will store the VM images
    # on the local OS disk in the LVM virtualization volume
    # if [ ${osbdNodeType} -eq ${osbdNodeTypeDemoSystem} -o \
    #      ${osbdNodeType} -eq ${osbdNodeTypeSingleServer} ]
    # then
    #     createLvmOsbdVolumeSizeInExtends \
    #         "100%FREE" "virtualization" "$osbdLvmVolumeGroup0"
    # fi
}


sub create_volume {
    my ($self, $group, $name, $size) = @_;

    die "Cannot create volume '$name' (size $size) on group '$group'"
    unless system("lvcreate --size $size --name $name $group") == 0;
}


# Create a LVM logical volume and give the size of the volume in logical extents
#
# This is usefull in case you would like to give the number of extents in
# percentage to the size of the volume group (suffix %VG) or the remainig free
# space (suffix %FREE) of the volume group.
# Consult the LVCREATE(8) manual page for more informations.
#
# Example:
#   Create a volume ('my_volume') which uses all free space available in
#   the volume group ('my_vg0')
#   lvmCreateVolumeSizeInExtends "100%FREE" "my_volume" "my_vg0"
sub create_volume_with_extents {
    my ($self, $extents, $name, $group) = @_;
    die "Cannot create volume with extents '$name'"
    unless system("lvcreate --extents $extents --name $name $group") == 0;
}

=head2 setup_filesystem

Creates partitions on the LVM.

=cut
sub setup_filesystem {
    my ($self) = @_;

    my $volume_group = '/dev/' . C('defaults.osbdLvmVolumeGroup0');

    my $fs_table = C('system.volumes');
    my @ordered_mounts = sort { $fs_table->{$a}->{order} <=> $fs_table->{$b}->{order} } keys %$fs_table;
    for my $name (@ordered_mounts) {
        my $fs = $fs_table->{$name};
        my $label = C('defaults.label_prefix') . $name;

        my $device = ($fs->{device} ? $fs->{device} : "$volume_group/$name" );

        if ($fs->{type} eq 'swap') {
            die "Unable to create swap partition '$label' on '$device'"
            if system("mkswap -L $label $device") != 0;
        } else {

            say "Creating XFS filesystem '$label' at '$device'";

            $self->create_xfs($label, $device);
            $self->mount($label, $fs->{mountpoint});
        }
    }

    # case "${osbdNodeType}" in
    #     ${osbdNodeTypeDemoSystem}|${osbdNodeTypeSingleServer})
    #         createOsbdFilesystem "virtual" \
    #             "/dev/${osbdLvmVolumeGroup0}/virtualization"
    #     ;;

    #     ${osbdNodeTypeStorageNode})
    #         createOsbdFilesystem "gfs-01" \
    #            "/dev/${osbdLvmVolumeGroup1}/${osbdGlusterVolumeName}"
    #     ;;
    # esac

}

=head2 create_xfs

Create XFS partition on the given device.

Parameters:

    $label Label of the XFS partition.
    $device Device path.

=cut
sub create_xfs {
    my ($self, $label, $device) = @_;

    die "Unable to create XFS filesystem '$label' on $device"
    unless system("mkfs.xfs -f -L $label $device > /dev/null") == 0;
}

=head2 mount

Mounts a partition.

Parameters:

    $label Label of the partition.
    $device Device path.

=cut
sub mount {
    my ($self, $label, $mount) = @_;

    # Prefix mount with system root
    my $path = File::Spec->catdir(C('system.root'), $mount);

    say "Mounting $label to $path";
    make_path $path unless -d $path;

    die "Unable to mount device with label '$label' to $path"
    if system("mount -L $label $path") != 0;

    # debug "Device with label '${label}' successfully mounted to ${mountPoint}"
}


1;
