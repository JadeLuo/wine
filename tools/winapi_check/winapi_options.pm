package winapi_options;

use strict;

sub parser_comma_list {
    my $prefix = shift;
    my $value = shift;
    if(defined($prefix) && $prefix eq "no") {
	return { active => 0, filter => 0, hash => {} };
    } elsif(defined($value)) {
	my %names;
	for my $name (split /,/, $value) {
	    $names{$name} = 1;
	}
	return { active => 1, filter => 1, hash => \%names };
    } else {
	return { active => 1, filter => 0, hash => {} };
    }
}

my %options = (
    "debug" => { default => 0, description => "debug mode" },
    "help" => { default => 0, description => "help mode" },
    "verbose" => { default => 0, description => "verbose mode" },

    "win16" => { default => 1, description => "Win16 checking" },
    "win32" => { default => 1, description => "Win32 checking" },

    "shared" =>  { default => 0, description => "show shared functions between Win16 and Win32" },
    "shared-segmented" =>  { default => 0, description => "segmented shared functions between Win16 and Win32 checking" },

    "local" =>  { default => 1, description => "local checking" },
    "module" => { 
	default => { active => 1, filter => 0, hash => {} },
	parent => "local",
	parser => \&parser_comma_list,
	description => "module filter"
    },

    "argument" => { default => 1, parent => "local", description => "argument checking" },
    "argument-count" => { default => 1, parent => "argument", description => "argument count checking" },
    "argument-forbidden" => {
	default => { active => 0, filter => 0, hash => {} },
	parent => "argument",
	parser => \&parser_comma_list,
	description => "argument forbidden checking"
    },
    "argument-kind" => {
	default => { active => 0, filter => 0, hash => {} },
	parent => "argument",
	parser => \&parser_comma_list,
	description => "argument kind checking"
    },
    "calling-convention" => { default => 0, parent => "local", description => "calling convention checking" },
    "misplaced" => { default => 0, parent => "local", description => "checking for misplaced functions" },
             
    "global" => { default => 1, description => "global checking" }, 
    "declared" => { default => 1, parent => "global", description => "declared checking" }, 
    "implemented" => { default => 0, parent => "global", description => "implemented checking" }

);

my %short_options = (
    "d" => "debug",
    "?" => "help",
    "v" => "verbose"
);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless ($self, $class);

    my $refarguments = shift;
    my @ARGV = @$refarguments;

    for my $name (sort(keys(%options))) {
        my $option = $options{$name};
	my $key = uc($name);
	$key =~ tr/-/_/;
	$$option{key} = $key;
	my $refvalue = \${$self->{$key}};
	$$refvalue = $$option{default};
    }

    my $files = \@{$self->{FILES}};
    my $module = \${$self->{MODULE}};
    my $global = \${$self->{GLOBAL}};

    $$global = 0;
    while(defined($_ = shift @ARGV)) {
	if(/^-([^=]*)(=(.*))?$/) {
	    my $name;
	    my $value;
	    if(defined($2)) {
		$name = $1;
		$value = $3;
            } else {
		$name = $1;
	    }
	    
	    if($name =~ /^([^-].*)$/) {
		$name = $short_options{$1};
	    } else {
		$name =~ s/^-(.*)$/$1/;
	    }
	    	   
	    my $prefix;
	    if($name =~ /^no-(.*)$/) {
		$name = $1;
		$prefix = "no";
		if(defined($value)) {
		    print STDERR "<internal>: options with prefix 'no' can't take parameters\n";
		    exit 1;
		}
	    }

	    my $option = $options{$name};
	    if(defined($option)) {
		my $key = $$option{key};
		my $parser = $$option{parser};
		my $refvalue = \${$self->{$key}};
	      	       
		if(defined($parser)) { 
		    $$refvalue = &$parser($prefix,$value);
		} else {
		    if(defined($value)) {
			$$refvalue = $value;
		    } elsif(!defined($prefix)) {
			$$refvalue = 1;
		    } else {
			$$refvalue = 0;
		    }
		}
		next;
	    }	 
	}
	
	if(/^--module-dlls$/) {
	    my @dirs = `cd dlls && find ./ -type d ! -name CVS`;
	    my %names;
	    for my $dir (@dirs) {
		chomp $dir;
		$dir =~ s/^\.\/(.*)$/$1/;
		next if $dir eq "";
		$names{$dir} = 1;
	    }
	    $$module = { active => 1, filter => 1, hash => \%names };
	}	
	elsif(/^-(.*)$/) {
	    print STDERR "<internal>: unknown option: $&\n"; 
	    print STDERR "<internal>: usage: winapi-check [--help] [<files>]\n";
	    exit 1;
	} else {
	    push @$files, $_;
	}
    }

    my $paths;
    if($#$files == -1) {
	$paths = ".";
	$$global = 1;
    } else {
	$paths = join(" ",@$files);
    }

    @$files = map {
	s/^.\/(.*)$/$1/;
	$_; 
    } split(/\n/, `find $paths -name \\*.c`);

    return $self;
}

sub show_help {
    my $self = shift;

    my $maxname = 0;
    for my $name (sort(keys(%options))) {
	if(length($name) > $maxname) {
	    $maxname = length($name);
	}
    }

    print "usage: winapi-check [--help] [<files>]\n";
    print "\n";
    for my $name (sort(keys(%options))) {
	my $option = $options{$name};
        my $description = $$option{description};
	my $default = $$option{default};
	
	my $output;
	if(ref($default) ne "HASH") {
	    if($default) {
		$output = "--no-$name";
	    } else {
		$output = "--$name";
	    }
	} else {
	    if($default->{active}) {
		$output = "--[no-]$name\[=<value>]";
	    } else {
		$output = "--$name\[=<value>]";
	    }
	}

	print "$output";
	for (0..(($maxname - length($name) + 14) - (length($output) - length($name) + 1))) { print " "; }
	if(ref($default) ne "HASH") {
	    if($default) {
		print "Disable $description\n";
	    } else {
		print "Enable $description\n";
	    }    
	} else {
	    if($default->{active}) {
		print "(Disable) $description\n";
	    } else {
		print "Enable $description\n";
	    }


	}
    }
}

sub AUTOLOAD {
    my $self = shift;

    my $name = $winapi_options::AUTOLOAD;
    $name =~ s/^.*::(.[^:]*)$/\U$1/;

    my $refvalue = $self->{$name};
    if(!defined($refvalue)) {
	die "<internal>: winapi_options.pm: member $name does not exists\n"; 
    }
    return $$refvalue;
}

sub files { my $self = shift; return @{$self->{FILES}}; }

sub report_module {
    my $self = shift;
    my $module = $self->module;
    
    my $name = shift;

    if(defined($name)) {
	return $module->{active} && (!$module->{filter} || $module->{hash}->{$name}); 
    } else {
	return 0;
    } 
}

sub report_argument_forbidden {
    my $self = shift;   
    my $argument_forbidden = $self->argument_forbidden;

    my $type = shift;

    return $argument_forbidden->{active} && (!$argument_forbidden->{filter} || $argument_forbidden->{hash}->{$type}); 
}

sub report_argument_kind {
    my $self = shift;
    my $argument_kind = $self->argument_kind;

    my $kind = shift;

    return $argument_kind->{active} && (!$argument_kind->{filter} || $argument_kind->{hash}->{$kind}); 

}

1;

