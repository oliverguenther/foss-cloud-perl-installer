package FOSSCloud::Installer::Steps::NetworkConfiguration;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use File::Path qw(make_path);
use IO::Interface::Simple;
use File::Basename;
use File::Spec;
use utf8;
use experimental 'smartmatch';

=head1 FOSSCloud::Installer::Steps::NetworkConfiguration

Create network from configuration.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

	$self->{network_config} = File::Spec->catfile(C('system.root'), 'etc/conf.d/net');
	$self->{selected_devices} = {};

    make_path(dirname($self->{network_config}));

    open(my $file, '>', $self->{network_config})
    or die "Cannot open network config file '$$self{network_config}'";

    say "[debug] Writing physical configuration";
    $self->writeStaticNetworkPhysicalConfiguration($file);

    if (C('network.use_bonding')) {
        say "[debug] Writing bonding configuration";
        $self->writeStaticNetworkBondingConfiguration($file);
    }

    if (C('network.use_vlan')) {
        say "[debug] Writing network vlan configuration";
        $self->writeStaticNetworkVlanConfiguration($file);
    }

    if (C('system.nodetype') ne 'storage') {
        # Configure bridging only on vm-, demo-nodes and single-server
        say "[debug] Writing network bridging configuration";
        $self->writeStaticNetworkBridgingConfiguration($file);
    }

    say "[debug] Writing DNS";
    $self->writeNetworkDnsResolver;
    say "[debug] Writing Hostname";
    $self->writeNetworkHostName;
    say "[debug] Writing OpenSSH configuration";
    $self->writeNetworkOpenSSHConfiguration;
    say "[debug] Network PostInstall";
    $self->writePostInstallNetworkConfig;

    close($file);
}

sub writeStaticNetworkPhysicalConfiguration {

	my ($self, $file) = @_;

    # Header
    print $file "#-----------------------------------------------------------------------------\n";
    print $file "# Physical interfaces\n";


    my $i = 1;
    for my $interface (C('network.interfaces')) {

    	# Add to init.d
        say "Adding symlink for $interface";
    	$self->add_init_symlink($interface);

        print $file "# physical interface #$i\n";

        if (C('system.nodetype') eq 'demo') {
            # On demo-systems add the pub network configuration to the first
            # physical interface
            my $ip = C('network.configuration.pub.ip');
            my $mask = C('network.configuration.pub.netmask');
            my $brd = C('network.configuration.pub.broadcast');
            my $domain = C('network.configuration.pub.domain');
            my $gw = C('network.gateway');
            my $host = C('network.hostname');

            print $file qq(config_${interface}="$ip/$mask brd $brd"\n);
            print $file qq(routes_${interface}="default via $gw\n");

            $self->host_entry("$ip\t$host.$domain ${host}");

        } else {
            # All other nodes use the physical interface as a bonding member
            # port, or as a VLAN interface, so no IP configuration will be done.
            print $file qq(config_$interface="null"\n);
        }

        print $file "\n";
        $i++;
    }
}

sub writeStaticNetworkBondingConfiguration {
	my ($self, $file) = @_;

    # Enslave all physical interfaces to an IEEE 802.3ad dynamic
    # link aggregation bond
    print $file "#-----------------------------------------------------------------------------\n";
    print $file "# Bonding interfaces\n";


    my $bonding_devices = join(' ', @{$self->{selected_devices}});

    print $file <<"END";
    slaves_bond0="$bonding_devices"
	lacp_rate_bond0="fast"
	miimon_bond0="100"
	mode_bond0="802.3ad"
	carrier_timeout_bond0="15"
	 
	config_bond0="null"
END

    $self->add_init_symlink("bond0");
    $self->add_to_runlevel("net.bond0");
}

sub writeStaticNetworkVlanConfiguration {
	my ($self, $file) = @_;

    # Header
    print $file "#-----------------------------------------------------------------------------\n";
    print $file "# VLAN (802.1q support)\n";

    # Create VLAN interfaces on top of the VLAN trunk interface, which is either
    # the bonding interface or on single-server installations without bonding,
    # the first physical interface.
    my $vlan_interface = "bond0";
    if (! C('network.use_bonding')) {
        $vlan_interface= $self->selected_devices->[0];
    }

    my $vlans = join(' ', map { $_->{vlanId} } @{$self->{interfaces}});
	print $file qq(vlans_$vlan_interface="$vlans");

    my $gw = C('network.gateway');
    my $host = C('network.hostname');

    # generating vlan interface configuration
    for my $network (@{$self->{networks}}) {

        my $vlanId = $network->{vlanId};
        my $ip = $network->{ip};
        my $mask = $network->{netmask};
        my $brd = $network->{broadcast};
        my $domain = $network->{domain};


        print $file "# $$network{name} VLAN\n";
        print $file qq(vlan${vlanId}_name="vlan${vlanId}"\n);

        if ($network->{name} eq 'pub'
        	&& C('system.nodetype') ~~ ['VmNode', 'Single']) {

            # VM nodes and single-server installations have the pub
            # vlan bridged with vmbr0, so no configuration will be done
            # on the vlan interface
            print $file qq(config_vlan${vlanId}="null"\n);
        } else {
        	print $file qq(config_vlan${vlanId}="${ip}/${mask} brd ${brd}"\n);
        }

        if ($network->{name} eq 'pub'
        	&& C('system.nodetype') ~~ ['StorageNode']) {

            # Append the default gateway to the public network.
            # VM nodes will have it on the bridging interface
            # (see below) and not directly on the VLAN interface.
            # This should be more flexible in the future as the default
            # gateway may be on a different network.
            print $file qq(routes_vlan${vlanId}="default via ${gw}"\n);
        }

        print $file "\n";

        if ($network->{name} eq 'int') {
        	$self->host_entry("${ip}\t${host}.${domain} ${host}");
        } else {
            $self->host_entry("${ip}\t${host}.${domain}");
        }
    }
}

sub writeStaticNetworkBridgingConfiguration {
	my ($self, $file) = @_;

    # Create an IEEE 802.1d bridge and configure
    print $file "#-----------------------------------------------------------------------------\n";
    print $file "# Bridging (802.1d) interfaces \n";

    my $is_demo = C('system.nodetype') eq 'demo';

    # On vm-nodes and single-server installations use the 'pub' network
    # configuration for the bridging interface
    # On demo systems, use the isolated pre-defined 'vmbr' network
    # configuration for the bridging interface
    my $network = C('network.configuration.' . ($is_demo ? 'vmbr' : 'pub'));

    my $vlanId = $network->{vlanId};
    my $ip = $network->{ip};
    my $mask = $network->{netmask};
    my $brd = $network->{broadcast};
    my $domain = $network->{domain};
    my $gw = C('network.gateway');

    if ($is_demo) {

        # Create an empty isolated bridge on demo systems
        print $file qq(brctl_vmbr0=""\n);

    } else {

        # Add the vlan pub interface to the bridge on vm-nodes and
        # single-server installations
        print $file qq(bridge_vmbr0="vlan${vlanId}"\n);
        print $file qq(bridge_add_vlan${vlanId}="vmbr0"\n);
    }

    print $file qq(config_vmbr0="${ip}/${mask} brd ${brd}"\n);

    if (!$is_demo) {

        # Only set a default route on vm-nodes and single-server installations
        print $file qq(routes_vmbr0="default via ${gw}"\n);

    }

    $self->add_init_symlink("vmbr0");
    $self->add_to_runlevel("net.vmbr0");
}

sub writeNetworkDnsResolver {
	my ($self) = @_;

	my $resolv_conf_file = File::Spec->catfile(C('system.root'), 'etc/resolv.conf');

    open(my $resolv_conf, '>', $resolv_conf_file)
    or die "Cannot open network config file '$resolv_conf_file'";

    # add the static name server configuration
    my $project_name = C('defaults.projectname');
	my $domain = C('network.configuration.int.domain');

    print $resolv_conf "# Generated by the ${project_name}-Installer\n";
    print $resolv_conf "domain $domain\n";

    for my $resolver (@{C('network.dns.resolver')}) {
        print $resolv_conf "nameserver $resolver\n";
    }

    close($resolv_conf);
}

sub writeNetworkHostName {
	my ($self) = @_;

	my $hostname_path = File::Spec->catfile(C('system.root'), 'etc/conf.d/hostname');

    open(my $hostname_file, '>', $hostname_path)
    or die "Cannot open hostname config file '$hostname_path'";

    my $hostname = C('network.hostname');
    print $hostname_file qq(hostname="$hostname"\n);

    close($hostname_file);
}

sub writeNetworkOpenSSHConfiguration {

	my $ssh_config;
    if (C('system.nodetype') eq 'demo') {

        # On demo nodes only one (public) interface is present
        $ssh_config = "ListenAddress " . C('network.configuration.pub.ip');
    } else {

        # On multi node installations listen on the 'admin' interface for
        # interactive SSH remote access and on the 'int' interface for
        # inter-node communication.
        $ssh_config = "ListenAddress " . C('network.configuration.admin.ip')
         . "\n" . "ListenAddress " . C('network.configuration.int.ip');
    }

    my $config_file = File::Spec->catfile(C('system.root'), 'etc/ssh/sshd_config');

   	my $code = system(qq(sed -i "s/^#?<FOSS-CLOUD-LISTEN-ADDRESS-CONFIG>\$/$ssh_config/" $config_file));
    die "Unable to change OpenSSH listening address"
    unless $code == 0;

}

sub writePostInstallNetworkConfig {
    my ($self) = @_;

    # Creates the post install network configuration CSV file, which will be
    # used by the node integration scripts after the first boot
    my $gw = C('network.gateway');
    my $host = C('network.hostname');

    my $sep = C('defaults.network.post_separator');

    # Load foss-cloud post network config file
    my $post_net_config = File::Spec->catfile(
    	C('system.root'),
    	'etc/foss-cloud/network.conf'
    );

	open(my $file, '>', $post_net_config)
	or die "Cannot open post network config file '$post_net_config'";

	for my $network (@{$self->{networks}}) {

        # Skip the internal 'vmbr' network, which is present on demo systems
		next if $network->{name} eq 'vmbr';

        my $vlanId = $network->{vlanId};
        my $ip = $network->{ip};
        my $mask = $network->{netmask};
        my $brd = $network->{broadcast};
        my $domain = $network->{domain};

        # write post-install network config
        print $file
        	"${host}${sep}${network}${sep}${vlanId}${sep}${ip}${sep}"
        	. "${domain}${sep}${mask}${sep}${brd}${sep}";

       	if ($network->{name} eq 'pub') {
            # Append the default gateway to the public network
            # This should be more flexible in the future as the default gateway
            # may be on a different network.
            print $file $gw;
        }

        print $file "\n";
    }

    close($file);
}

sub host_entry {
	my ($self, $entry) = @_;

	my $host_file = File::Spec->catfile(C('system.root'), '/etc/hosts');

    open(my $file, '>>', $host_file)
    or die "Cannot open hosts file '$host_file'";

    print $file $entry;
    close($file);
}

sub validate_interface {
	my ($self, $interface) = @_;

	# TODO
}

sub add_init_symlink {
	my ($self, $interface_name) = @_;

	my $root = C('system.root');

    # debug "Adding ${interface} init script symlink"
    my $source = '/etc/init.d/net.lo';
    my $target = "/etc/init.d/net.$interface_name";

    my $code = system(qq(chroot $root ln --force --symbolic $source $target));

    die "Unable to set symbolic init script link for interface '$interface_name'"
    unless $code == 0;
}

sub add_to_runlevel {
	my ($self, $service, $level) = @_;
	$level //= 'default';

    # debug "Adding ${service} to ${runlevel}"

    my $root = C('system.root');
    my $code = system(qq(chroot $root rc-update add $service $level > /dev/null));

    die "Unable to add $service to $level"
    unless $code == 0;
}

1;