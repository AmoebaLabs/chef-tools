package Amoeba;
use v5.12;
use strict;
use warnings;
use autodie;
use JSON qw(encode_json decode_json);
use File::Temp qw(tempfile);

use Exporter 'import';
our @EXPORT = qw(
  read_file write_file read_json write_json
  read_bag write_bag
  require_node require_kitchen
  provider_info deploy_info
  ensure_deployer node_cmd bundle_exec
  knife_solo knife_solo_json ssh_node
);

sub read_file(_) {
    no autodie;
    open my $fh, '<', shift or return;
    join '', <$fh>
}
sub write_file {
    open my $fh, '>', shift;
    print $fh @_
}
sub read_json { decode_json( read_file shift or return ) }
sub write_json { write_file shift, encode_json shift }

sub require_node {
    my $node_name = shift(@ARGV) or die "Must provide node name.\n";
    my $node = read_json "nodes/$node_name.json"
            or die "Could not open node json file.\n";
    $$node{fqdn} = $$node{name};
    $$node{name} = $node_name;
    return $node;
}
sub require_kitchen {
    die "Must be in kitchen.\n"
            unless map {-e} qw(authorized_keys nodes data_bags);
}

sub write_bag {
    my ($bag, $key, $data) = @_;
    $$data{id} = $key;
    mkdir "data_bags/$bag" unless -d  "data_bags/$bag";
    write_json "data_bags/$bag/$key.json", $data
}
sub read_bag {
    my ($bag, $key) = @_;
    read_json "data_bags/$bag/$key.json"
}

sub provider_info {
    my ($node) = @_;
    my $node_deploy = $$node{deployment};
    my $remote_node = read_bag(nodes => $$node{name}) // {};
    my %remote_combined = $$remote_node{deployment} ? %{$$remote_node{deployment} // {}} : (
        %{$$remote_node{default}{deployment} // {}}, %{$$remote_node{override}{deployment} // {}}
    );
    my $provider = read_bag(providers => $$node_deploy{provider}) // {};
    return { %$provider, %remote_combined, %$node_deploy };
}
sub deploy_info {
    my ($node) = @_;
    my $dep = provider_info $node;
    my $hostname = $$dep{user} ? "$$dep{user}\@$$dep{host}" : $$dep{host};
    my %params = map { $_ => $$dep{$_} } qw(port ident host);
    return ($hostname, \%params)
}
sub node_cmd {
    my ($node, $labels, @args) = @_;
    my ($hostname, $flags) = deploy_info $node;
    $flags = join ' ', map {
        $$flags{$_} ? "$$labels{$_} $$flags{$_}" : ''
    } keys %$labels;
    return ($hostname, $flags, @args);
}
sub bundle_exec {
    system join ' ', qw(bundle exec), @_
}
sub knife_solo {
    my ($node, $cmd, @args) = @_;
    bundle_exec qw(knife solo), $cmd => node_cmd $node => {
        port    => '--ssh-port',
        config  => '--ssh-config-file',
        ident   => '--identity-file'
    }, (
        '--node-name' => $$node{name}
    ), @args, "nodes/$$node{name}.json";
    0 == $? >> 8
}
sub knife_solo_json {
    my ($node, $json, $cmd, @args) = @_;
    my ($fh, $filename) = tempfile();
    $$json{deployment} = { %{provider_info($node)}, %{$$json{deployment} // {}} };
    print $fh encode_json $json;
    bundle_exec qw(knife solo), $cmd => node_cmd $node => {
        port    => '--ssh-port',
        config  => '--ssh-config-file',
        ident   => '--identity-file'
    }, (
        '--node-name' => $$node{name}
    ), @args, $filename;
    0 == $? >> 8
}
sub ssh_node {
    my ($node, $cmd, @args) = @_;
    ensure_deployer($node);
    system join ' ', ssh => node_cmd $node => {
        port    => '-p',
        ident   => '-i'
    }, @args, ($cmd ? "'$cmd'" : ());
    0 == $? >> 8
}
sub ensure_deployer {
    my ($node) = @_;
    write_bag nodes => $$node{name}, {
        deployment => {
            user  => 'deploy',
            ident => undef
        }
    } unless read_bag nodes => $$node{name}
}

package Dispatch::GitLike;
use v5.12;
use strict;
use warnings;
use autodie;
use File::Basename;

sub new {
    my ($class, %opts) = @_;
    my $path = $opts{path} // [ split ':', $ENV{PATH} ];
    my $base = $opts{base} // (($0 and $0 ne '-') ? basename($0)
                        : die "Error: Cannot resolve command basename.\n");
    my $external = $opts{external} // 1;
    my $default  = $opts{default}  // 'help';
    my $commands = {
        help   => sub {
            my $self = shift;
            print STDERR "Possible commands:\n",
                            map {"\t$_\n"} sort keys %{$$self{commands}};
        },
        ( map {
            my ($name, $cmd) = @$_;
            $name => ref($cmd) ? $cmd : sub { system($cmd, @ARGV) >> 8 }
        } pairs (
            %{$opts{commands}},
            find_external({ base => $base, path => $path })
        )),
    };
    # Group subcommands
    my %cmd_groups;
    for (keys %$commands) {
        my @parts = split /-+/;
        if (@parts > 1) {
            push @{$cmd_groups{$parts[0]}},
                [ join('-', @parts[1..$#parts]) => $$commands{$_} ];
            delete $$commands{$_};
        }
    }
    for (keys %cmd_groups) {
        my $subcmd = $_;
        $$commands{$subcmd} = sub {
            Dispatch::GitLike->new(commands => {
                map { @$_ } @{$cmd_groups{$subcmd}}
            })->run(@ARGV);
        }
    }
    my $self = bless {
        external => $external,
        default  => $default,
        commands => $commands,
        path     => $path,
        base     => $base,
    }, $class;
    return $self;
}
sub run {
    my ($self, @argv) = @_;
    my $cmd = (@argv and $argv[0] !~ /^-/) ? shift(@argv) : $$self{default};
    die "Error: Could not resolve command '$$self{base} $cmd'.\n"
            unless exists $$self{commands}{$cmd};
    local @ARGV = @argv;
    local $0 = "$$self{base}-$cmd";
    local $ENV{PATH} = join ':', @{$$self{path}};
    $$self{commands}{$cmd}->($self, $cmd, @argv)
}

sub find_external {
    my ($base, $path) = @{$_[0]}{'base', 'path'};
    map {
        my $cmdpath = $_;
        m|/$base-([^/]+)$| ? ( do {
            my $k = $1;
            $k =~ s/\.[^.]+$//;
            $k
        } => $cmdpath ) : ()
    } sort grep { -x } map { glob "$_/$base-*" } ('.', @$path)
}
sub pairs {
    my %hash = @_;
    my @pairs;
    while (my ($k, $v) = each %hash) {
        push @pairs, [ $k => $v ]
    }
    return @pairs
}

1
