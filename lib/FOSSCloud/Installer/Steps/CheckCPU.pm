package FOSSCloud::Installer::Steps::CheckCPU;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use IPC::Run qw(run);
use feature 'switch';
use utf8;

=head1 FOSSCloud::Installer::Steps::CheckCPU

Runs CPU checks unless 'skip-cpu-check' was set.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    # Parse procinfo for following tests
    unless ($params->{'skip-cpu-check'}) {
        $self->_parse_procinfo;
    	return $self->check;
    }
}

=head2 check

Runs CPU checks.

=cut
sub check {
	my $self = shift;

    if ($self->proc_match('vendor_id', 'GenuineIntel')) {
        say 'Detected an "Intel" CPU';
	} elsif ($self->proc_match('vendor_id', 'AuthenticAMD')) {
        say 'Detected an "AMD" CPU';
        warn C('defaults.projectname') . " wasn't tested on \"AMD\" CPUs";
    } else {
        die "Your CPU is not supported";
    }

    if (!($self->proc_match('flags', 'vmx')
        || $self->cpuHasFlag('flags', 'svm'))) {
        die 'Your CPU misses support for the virtualization extension'
            . 'You need a CPU with either the "Intel VT" or "AMD-V" extension.'
            . 'If your CPU has virtualization support it might be disabled in the BIOS';
    }

    # VERBOSE info "Your CPU \"${cpuModelName}\" is supported"
}

=head2 proc_match

Returns 1 if any processor entry
matches the key regex.

Parameters:

    $key: the key to match in
    $regex: regex value to look for

=cut
sub proc_match {
    my ($self, $key, $regex) = @_;

    for my $proc (@{$self->{cpus_procinfo}}) {
        if (defined($proc->{$key})) {
            return 1 if ($proc->{$key} =~ $regex);
        }
    }
}

=head2 _parse_procinfo

Loads all processor entries in
config CPU_PROC_CPUINFO (`/proc/cpuinfo`)
as kvp.

=cut
sub _parse_procinfo {
    my ($self) = @_;

    my $out;
    my @info;
    my $procId = 0;
    run ['cat', '/proc/cpuinfo'], \undef, \$out;

    for my $line (split /\n/, $out) {
        chomp $line;

        my ($item, $value) = split qr/\s*:\s*/, $line, 2;
        next unless defined($item);

        if ($item eq 'processor') {
          $procId = $value;
          $info[$procId] = {};
          next;
        }

        $info[$procId]->{$item} = $value;
    }

    $self->{cpus_procinfo} = \@info;
}

1;