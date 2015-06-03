package FOSSCloud::Installer::Steps::CheckMemory;

use FOSSCloud::Installer::Config;
use Modern::Perl;
use IPC::Run qw(run);
use feature 'switch';
use utf8;

=head1 FOSSCloud::Installer::Steps::CheckMemory

Runs Memory checks unless 'skip-memory-check' was set.

=cut
sub new {
	my ($class, $params) = @_;

	my $self = {};
	bless $self, $class;

    return if ($params->{'skip-memory-check'});

    my $available = $self->parse_free_memory;

    if (!defined($available)) {
        die "Could not read available memory from '/proc/meminfo'";
    }
    elsif ($available < C('defaults.requirements.memory')) {
        die "You don't have enough memory ($available GB).";
    }
}

=head2 parse_free_memory

Returns free memory in GB from `/proc/meminfo`

=cut
sub parse_free_memory {
    my ($self) = @_;

    my $out;
    run ['cat', '/proc/meminfo'], \undef, \$out;

    if ($out =~ qr/MemTotal:\s*(\d+)/i) {
        return $1 / 1024 / 1024;
    }
}

1;