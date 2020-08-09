#!/usr/bin/perl -w

$in_function = 0;

# ==================== Main ====================
while (<>){
    chomp $_;
    if ($_ eq ""){
        print "\n";
        next;
    }
    $comment = "";
    # Comment after line
    get_and_remove_comments();
    # TODO split ';' into multiple lines
    $indent = get_indentation($_);

    if ($_ eq ""){
        print indent(append_comment("")) . "\n";
        next;
    }

    my $line = translate($_);
    $line = replace_argv($line);
    $line = append_comment($line);
    print indent($line) . "\n" if $line ne "" && $line ne "\n";
}

# ==================== Functions ====================

# Get Comments after line
sub get_and_remove_comments {
    return if $_ eq "#!/bin/dash";
    if (/^[^\$]*(#.*)$/){
        s/(\s*)(#.*)//;
        $comment = "$1$2";
    }
}

sub append_comment {
    my ($line) = @_;
    $line .= $comment;
    return $line;
}

# Get indentation
sub get_indentation {
    my $space = 0;
    while (/^\s/){
        $_ =~ s/^\s//;
        $space++;
    }
    return $space - 1;
}

# Indent the given string
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
    # Shell functions
    $line = translate_sys_cmd($_);
    return $line if $line ne "";
    # Variable Assignment
    $line = translate_var_assignment($_);
    return $line if $line ne "";
    # If Statement
    $line = translate_if_statement($_);
    return $line if $line ne "";
    # For loop
    $line = translate_for_loop($_);
    return $line if $line ne "";
    # While loop
    $line = translate_while_loop($_);
    return $line if $line ne "";
    # Else
    $line = translate_unknown_cmd($_);
    return $line;
}

# Translate unrecognised system command
sub translate_unknown_cmd {
    my ($cmd) = @_;
    return "system \"$cmd\";";
}

# Translate system command
sub translate_sys_cmd {
    my ($statement) = @_;
    if ($statement =~ /^(\w+)\s(.*)/) {
        my $cmd = $1;
        my $args = $2;

        # =============== echo ===============
        if ($cmd eq "echo"){
            my $retval = "";
            my $newline = "\\n";
            # Case 0: -n
            $newline = "" if ($args =~ s/\s?(-n)\s?//);
            # Case 1: Double quote
            if ($args =~ /^"(.*)"/) {
                my $string = $1;
                $string =~ s/\\/\\\\/g;
                $string =~ s/\\\\"/\\"/g;
                $retval = "print \"$string$newline\";";
            }
            # Case 2: Single quote
            if ($args =~ /^'(.*)'$/) {
                my $string = $1;
                $string =~ s/\\/\\\\/gi;
                $string =~ s/'\\''/'/gi;
                $string =~ s/"/\\"/g;
                $retval = "print \"$string$newline\";";
            }
            # Case 3: No quote
            $retval = "print \"$args$newline\";" if $retval eq "";
            return $retval;
        }

        # =============== test ===============
        elsif ($cmd eq "test"){
            return parse_test_statement($args)
        }

        # =============== expr ===============
        elsif ($cmd eq "expr"){
            return parse_expr($args);
        }

        # =============== cd ===============
        elsif ($cmd eq "cd"){
            return "chdir '$args';";
        }
        # =============== exit ===============
        elsif ($cmd eq "exit"){
            return $_ . ";";
        }
        elsif ($cmd eq "read"){
            return "\$$args = <STDIN>;" . indent("chomp \$$args;");
        }
    }
}

# Translate program header
sub translate_header {
    return "#!/usr/bin/perl -w" if /#!\/bin\/dash/;
}

# Translate variable assignment
sub translate_var_assignment {
    return "\$$1 = '$2';" if (/^(\w+)=(\w+)$/);
    if (/^(\w+)=`(.+)`/) {
        return "\$$1 = " . parse_backquote($2) . ";";
    } elsif (/^(\w+)=\$\(\((.+)\)\)/) {
        return "\$$1 = " .  parse_expr($2) . ";"
    }
    elsif (/^(\w+)=\$\((.+)\)/) {
        return "\$$1 = " . parse_backquote($2) . ";"
    } elsif (/^(\w+)=\$(.+)$/) {
        return "\$$1 = \$$2;";
    }
}

# Translate for loop
sub translate_for_loop {
    # Case 1: done
    return "}" if /^done/;
    # Case 2: do
    return "\n" if /^do/;
    # Case 3: for () in ()
    if (/^for (.+) in (.*)/){
        my $variable = ($1);
        my $list = process_loop_list($2);
        return "foreach \$$variable ($list) {";
    }
}

# Translate if statement
sub translate_if_statement {
    return "\n" if /^then/;
    my ($line) = @_;
    if (/^if (.*)/) {
        my $condition = parse_test_statement($1);
        return "if ($condition) {";
    } elsif (/^elif (.*)/) {
        my $condition = parse_test_statement($1);
        return "} elsif ($condition) {";
    } elsif (/^else/) {
        return "} else {";
    } elsif (/^fi/) {
        return "}";
    }
}

# Translate while loop
sub translate_while_loop {
    my ($line) = @_;
    if (/^while (.*)/) {
        my $condition = parse_test_statement($1);
        return "while ($condition) {";
    }
}

# Process for loop list
sub process_loop_list {
    my ($string) = @_;
    # $string =~ s/^["']?//;
    # $string =~ s/["']?$//;
    my @sub_string = split(/\s+/, $string);
    my $tmp = "";
    my @list = ();

    # GLOB
    if ($string =~ /\*\.[\w]+$/) {
        return "glob(\"$string\")";
    } 

    # The following code snippet is referenced from 
    # https://www.perlmonks.org/?node_id=212179
    # --------- Start snippet ---------
    foreach (@sub_string) {
        if (/^["'][^"']["']$/){
            push @list, "$_";
        }
        elsif (/^["'].+/) {
            $tmp = "$_";
            next;
        } elsif (/.+["']$/){
            push @list, "$tmp $_";
            $tmp = "";
        } elsif ($tmp && /.+/){
            $tmp .= " $_";
        } else {
            push @list, "$_";
        }
    }
    # --------- End of snippet ---------

    if ($#list + 1 > 1){
        foreach (@list){
            $_ =~ s/^['"]//g;
            $_ =~ s/['"]$//g;
        }
        my $retval = join("', '", @list);
        return "'" . $retval . "'";
    }
    else {
        foreach (@list){
            $_ =~ s/^['"]//g;
            $_ =~ s/['"]$//g;
        }
        my $retval = join("', '", @list);
        return "'" . $retval . "'";
    }

}

sub replace_argv {
    my ($line) = @_;
    $line =~ s/\$@/\@ARGV/g;
    $line =~ s/\$\*/\@ARGV/g;
    $line =~ s/\$#/\$#ARGV + 1/g;
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

# Process various test synopsis
sub parse_test_statement {
    my ($statement) = @_;
    if ($statement =~ /^test (.*)$/){
        return parse_condition($1);
    } elsif ($statement =~ /\[ (.*) \]/){
        return parse_condition($1);
    }
    my $other = parse_condition($1);
    return $other if $other ne "";
}

# Process conditions
sub parse_condition {
    my ($condition) = @_;
    
    # True / False
    if    ($condition eq "true") { return "1"; }
    elsif ($condition eq "false") { return "0"; } 

    # 2 Argument comparison
    $condition =~ /^(.+) (.+) (.+)/;
    if ($3){
        # Parameter process
        my $p1 = parse_condition_args($1);
        my $p2 = parse_condition_args($3);
        # String
        if    ($2 eq "=")   { return "$p1 eq $p2"; }    #  ()  =  ()  ->  () eq ()
        elsif ($2 eq "!=")  { return "$p1 ne $p2"; }    #  ()  != ()  ->  () ne ()
        # Numeric
        elsif ($2 eq "-eq") { return "$p1 == $p2"; }    #  () -eq ()  ->  () == ()
        elsif ($2 eq "-ge") { return "$p1 >= $p2"; }    #  () -ge ()  ->  () >= ()
        elsif ($2 eq "-gt") { return "$p1 > $p2";  }    #  () -gt ()  ->  () >  ()
        elsif ($2 eq "-le") { return "$p1 <= $p2"; }    #  () -le ()  ->  () <= ()
        elsif ($2 eq "-lt") { return "$p1 < $p2";  }    #  () -lt ()  ->  () <  ()
        elsif ($2 eq "-ne") { return "$p1 != $p2"; }    #  () -ne ()  ->  () != ()
    } else {
        $condition =~ /^(.+) (.+)/;
        # Parameter process
        my $p = parse_condition_args($2);
        # Zero / Non-zero String
        if    ($1 eq "-n") { return "$p != \"\""; }     # -n ()  ->  () != ""
        elsif ($1 eq "-z") { return "$p == \"\""; }     # -z ()  ->  () == ""
        # File operations
        if ($1 eq "-r" || 
            $1 eq "-d" ||
            $1 eq "-f ") { return "$1 $p"; }
    }

    # Subset 4
    # && 
    # || Operation
}

# Process argument in conditional statement
sub parse_condition_args {
    my ($param) = @_;
    if ($param =~ /^\$(.*)/){
        return $param;
    } elsif ($param =~ /['"]/) {
        return "quote not implemented";
    } else {
        return "\'$param\'";
    }
}

sub parse_backquote {
    my ($statement) = @_;
    # print $statement. "\n";
    return translate_sys_cmd($statement);
}

sub parse_expr {
    my ($args) = @_;
    $args =~ s/^(\$?\w+)//;
    my $expr = $1;
    $expr =~ s/\$?(\w+)/\$$1/g  if ($expr =~ /[A-Za-z]/g);

    while ($args =~ s/^\s*([-+*%\/])\s*(\$?\w+)//) {
        my $p = $2;
        $p =~ s/\$?(\w+)/\$$1/g if ($2 =~ /[A-Za-z]/g);
        $expr .= " $1 $2";
    }
    return $expr;
}
