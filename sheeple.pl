#!/usr/bin/perl -w

@dash_cmd = ("ls","pwd","id","date");
$in_function = 0;

while (<>){
    chomp $_;
    $indent = get_indentation($_);
    my $line = translate($_);
    $line = replace_argv($line);
    print indent($line) . "\n" if $line ne "";
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
    $line = translate_header($_);
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
    $line = translate_if_statement($_);
    return $line if $line ne "";

}

sub translate_sys_cmd {
    # =============== echo =============== 
    # Case 1: Double quote
    if (/^echo "(.*)"/) {
        my $string = $1;
        $string =~ s/\\/\\\\/g;
        $string =~ s/\\\\"/\\"/g;
        return "print \"$string\\n\";";
    }
    # Case 2: Single quote 
    if (/^echo '(.*)'$/) {
        my $string = $1;
        $string =~ s/'\\''/'/gi;
        $string =~ s/"/\\"/g;
        return "print \"$string\\n\";";
    }
    # Case 3: No quote
    return "print \"$1\\n\";" if /^echo (.*)$/;

    # =============== cd =============== 
    return "chdir '$1';" if /^cd (.*)/;

    # =============== exit ===============
    return $_ . ";" if /^exit/;
    return "\$$1 = <STDIN>;" . indent("chomp \$$1;") if /^read (.*)/;

    # =============== etc =============== 
    foreach $cmd (@dash_cmd) {
        return "system \"$_\";" if /^($cmd)(\s.+)?/;
    }
}

sub translate_header {
    return "#!/usr/bin/perl -w" if /#!\/bin\/dash/;
}

sub translate_var_assignment {
    return "\$$1 = '$2';" if (/^(\w+)=(\w+)$/);
}

# TODO: Comment after code on the same line
sub translate_comment {
    return $_ if /^#/;
}

sub translate_for_loop {
    # Case 1: done
    return "}" if /^done/;
    # Case 2: do
    return "" if /^do/;
    # Case 3: for () in ()
    if (/^for (.+) in (.*)/){
        my $variable = ($1);
        my $list = process_loop_list($2);
        return "foreach \$$variable ($list) {";
    }
}

sub translate_if_statement {
    return "" if /^then/;
    my ($line) = @_;
    if (/^if (.*)/) {
        my $condition = parse_condition($1);
        return "if ($condition) {";
    } elsif (/^elif (.*)/) {
        my $condition = parse_condition($1);
        return "} elsif ($condition) {";
    } elsif (/^else/) {
        return "} else {";
    } elsif (/^fi/) {
        return "}";
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

sub replace_argv {
    my ($line) = @_;
    if ($in_function) {

    } else {
        while ($line =~ /\$([0-9])/){
            my $index = $1;
            my $argv_index = $index - 1;
            $line =~ s/\$$index/\$ARGV[$argv_index]/g;
        }
        return $line;
    }
}

sub parse_condition {
    my ($condition) = @_;
    # String Compare
    if ($condition =~ /^test (.+) = (.+)/) {
        return "'$1' eq '$2'";
    }
    # TODO: Numeric compare
    # TODO: File operation
    # TODO: operator !
}