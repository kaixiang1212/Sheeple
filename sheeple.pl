#!/usr/bin/perl -w

@dash_cmd = ("ls","pwd","id","date");


while (<>){
    chomp $_;
    $indent = get_indentation($_);
    my $line = translate($_);
    
    print indent($line) if $line ne "";
}

sub get_indentation {
    my $space = 0;
    while (/^\s/){
        $_ =~ s/^\s//;
        $space++;
    }
    return $space;
}

sub indent {
    my ($line) = @_;
    if ($indent != 0) {
        for my $i (0..$indent) {
            $line = " " . $line;
        }
    }
    return $line;
}

sub translate {
    $_ =~ s/^\s+//;
    # New Line
    return "\n" if $_ eq "";
    # Header
    my $line = translate_header($_);
    return $line if $line ne "";
    # Comments
    $line = translate_comment($_);
    return $line if $line ne "";
    # Shell functions
    $line = translate_sys_cmd($_);
    return $line if $line ne "";
    # Variable Assignment
    $line = translate_var_assignment($_);
    return $line if $line ne "";
    # For loop
    $line = translate_for_loop($_);
    return $line if $line ne "";

}

sub translate_sys_cmd {
    # =============== echo =============== 
    # Case 1: Double quote
    if (/^echo "(.*)"/) {
        my $string = $1;
        $string =~ s/\\/\\\\/g;
        $string =~ s/\\\\"/\\"/g;
        return "print \"$string\\n\";" . "\n" ;
    }
    # Case 2: Single quote 
    if (/^echo '(.*)'$/) {
        my $string = $1;
        $string =~ s/'\\''/'/gi;
        return "print \"$string\\n\";" . "\n";
    }
    # Case 3: No quote
    return "print \"$1\\n\";" . "\n" if /^echo (.*)$/;

    # =============== cd =============== 
    return "chdir '$1';" . "\n" if /^cd (.*)/;

    # =============== exit ===============
    return $_ . ";\n" if /^exit/;
    return "\$$1 = <STDIN>;\n" . indent("chomp \$$1;") . "\n" if /^read (.*)/;

    # =============== etc =============== 
    foreach $cmd (@dash_cmd) {
        return "system \"$_\";" . "\n" if /^($cmd)(\s.+)?/;
    }
}

sub translate_header {
    return "#!/usr/bin/perl -w" . "\n" if /#!\/bin\/dash/;
}

sub translate_var_assignment {
    return "\$$1 = '$2';" . "\n" if (/^(\w+)=(\w+)$/);
}

sub translate_comment {
    return $_ . "\n" if /^#/;
}

sub translate_for_loop {
    # Case 1: done
    return "}" . "\n" if /^done/;
    # Case 2: do
    return "" if /^do/;
    # Case 3: for () in ()
    if (/^for (.+) in (.*)/){
        my $variable = ($1);
        my $list = process_loop_list($2);
        return "foreach \$$variable ($list) {" . "\n";
    }
}

# Process for loop list
sub process_loop_list {
    my ($string) = @_;
    my @sub_string = split(/\s/, $string);

    # Case 1: More than 1 args in the field
    if ($#sub_string + 1 != 1){
        my $retval = join("', '", @sub_string);
        return "'" . $retval . "'";
    }
    # Case 2: File
    else {
        return "glob(\"$string\")";
    }

}