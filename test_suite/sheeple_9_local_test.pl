#!/usr/bin/perl -w

$SRC_filename = $ARGV[0];

# DES output to a file for test comparison only 
$DES_filename = 'z';

open (SRC, '<', $SRC_filename) or die "Can not open file.\n";
@file_content = <SRC>;
close (SRC);

open (DES, '>', $DES_filename) or die "Can not open file.\n";

sub first_line_env {
    my ($l) = @_;
    if ($l =~ /^\#\!\/.*/) {
        print DES "#!/usr/bin/perl -w\n";
    }
}

sub copy_comments {
    my ($l) = @_;
    if ($l =~ /^\#\s+(.*)/) {
        print DES "$l";
    }
}

sub equal_n_dollar {
    my ($l) = @_;
    if ($l !~ /if .*/){
        if ($l =~ /\s*(.*)\=(.*)/) {
            if ($for_flag eq 1) {
                print DES "    ";
            }
            if ($while_loop eq 1) {
                print DES "    ";
            }
            my $j = $1;
            my $k = $2;
            # print "$k\n";
            if ($k =~ /^\$(.+)/) {
                if ($k =~ /\$\(\((.*)\)\)(.*)/) {
                    # for seq math
                    print DES "\$$j = \$$1\;$2\n";
                } else {
                    # if the second var is starting with dollar
                    print DES "\$$j = $k\;\n";
                }
            } elsif ($k =~ /\`expr (.*)\`(.*)/){
                # for seq expr including comments
                print DES "\$$j = $1\;$2\n";
            } else {
                # plain string assignment which only adds quotes is good
                print DES "\$$j = \'$k\'\;";
                print DES "\n";
            }
        }
    }
}

sub echo_function {
    my ($l) = @_;
    # match single quotes
    if ($l =~ /(\s*)echo \'(.*)\'/) {
        # check if in for loop
        if ($for_flag eq 1) {
            print DES "    ";
        }
        if ($while_loop eq 1) {
            print DES "    ";
        }
        $t = $2;
        # check if contain doule quotes there
        # for truth.sh
        if ($t =~ /\s*\"(.*)\"(.*)/) {
            print DES 'print "\"';
            print DES "$1";
            print DES '\"';
            print DES "$2";
            print DES '\n";';
            print DES "\n";
        } else {
            print DES "print \"$t";
            print DES '\n";';
            print DES "\n";
        }
    # match double quotes
    } elsif ($l =~ /\s*echo \"(.+)\"/) {
        if ($for_flag eq 1) {
            print DES "    ";
        }
        if ($while_loop eq 1) {
            print DES "    ";
        }
        print DES "print \"$1\\n\"\;\n";
    # match echo following without any quotes
    } elsif ($l =~ /(\s*)echo(\s+)(.*)/) {
        # check for loop
        if ($for_flag eq 1) {
            print DES "    ";
        } 
        if ($while_loop eq 1) {
            print DES "    ";
        }
        # check if 
        elsif ($if_flag eq 1 && $elif_flag eq 0) {
            print DES "    ";
            $if_print_flag = 1;
        }
        elsif ($elif_flag eq 1 && $elif_print_flag eq 1) {
            print DES "        ";
            $elif_print_flag = 1;
        }
        print DES "print \"$3\\n\"\;";
        print DES "\n";
    }
}

sub system_function {
    my ($l) = @_;
    if ($l =~ /pwd/) {
        if ($for_flag eq 1) {
            print DES "    ";
        }
        print DES "system \"pwd\"\;";
        print DES "\n";
    }
    if ($l =~ /(.*ls.*)/) {
        if ($l !~ /else/) {
            if ($for_flag eq 1) {
                print DES "    ";
            }
            print DES "system \"$1\"\;";
            print DES "\n";
        }
    }
    if ($l =~ /id\s+/) {
        if ($for_flag eq 1) {
            print DES "    ";
        }
        print DES "system \"id\"\;";
        print DES "\n";
    }
    if ($l =~ /date/) {
        if ($for_flag eq 1) {
            print DES "    ";
        }
        print DES "system \"date\"\;";
        print DES "\n";
    }
    if ($l =~ /(gcc.*)/) {
        if ($l !~ /echo gcc/) {
            if ($for_flag eq 1) {
                print DES "    ";
            }
            print DES "system \"$1\"\;";
            print DES "\n";
        }
    }
}

sub copy_empty_line {
    my ($l) = @_;
    if ($l =~ /^\s*$/) {
        print DES "\n";
    }
}

sub for_loop {
    my ($l) = @_;
    if ($l =~ /for (.+) in (.+)\n/) {
        # check for c files
        if ($l =~ /for (.+) in (\*\.c)\n/) {
            print DES "foreach \$$1 (";
            print DES "glob\(\"$2\"\)";
            print DES ") {\n";
        } else {
            # if not c files just split by space then add quotes
            my @vars = split / /, $2;
            foreach my $s (@vars) {
                if ($s !~ /\d+/) {
                    $s = "\'$s\'";
                }
            }
            print DES "foreach \$$1 (";
            print DES join ', ', @vars;
            print DES ") {\n";
        }
    }

}

sub read_function {
    my ($l) = @_;
    if ($l =~ /read (.+)/) {
        if ($for_flag eq 1) {
            print DES "    ";
        }
        print DES "\$$1 = <STDIN>\;";
        print DES "\n";
        if ($for_flag eq 1) {
            print DES "    ";
        }
        print DES "chomp \$$1\;";
        print DES "\n";
    }
}

sub cd_function {
    my ($l) = @_;
    if ($l =~ /cd (.+)/) {
        if ($for_flag eq 1) {
            print DES "    ";
        }
        print DES "chdir \'$1\'\;";
        print DES "\n";
    }
}

sub exit_function {
    my ($l) = @_;
    if ($l =~ /exit (.+)/) {
        if ($for_flag eq 1) {
            print DES "    ";
        }
        print DES "exit $1\;";
        print DES "\n";
    }
}

sub check_argument {
    my ($l) = @_;
    # check for var $\d in bash and change to $ARGV[\d] 
    if ($l =~ /(.*)\$(\d+)(.*)/) {
        my $arg_part_1 = $1;
        my $n = $2 - 1;
        my $arg_part_2 = $3;
        my $result = "$arg_part_1\$ARGV\[$n\]$arg_part_2";
        return $result;
    } elsif ($l =~ /(.*)\"\$\@\"(.*)/) {
        my $result = "$1\@ARGV$2";
        return $result;
    } else {
        return $l;
    }
}


sub if_condtion {
    my ($l) = @_;
    if ($l =~ /^if (.+)\n/) {
        my $i = $1;
        $if_flag = 1;
        # if test two var equal
        if ($i =~ /test ([a-zA-Z]*) = ([a-zA-Z]*)/){
            print DES "if \(\'$1\' eq \'$2\'\) \{\n"
        } elsif ($i =~ /\[ -d (.*) \]/) {
            # if [ -d ] 
            print DES "if \(\-d \'$1\'\) \{\n";
        } elsif ($i =~ /test \-d (.+)/) {
            # if test -d
            print DES "if \(\-d \'$1\'\) \{\n";
        } elsif ($i =~ /test \-r (.+)/) {
            # if test -r
            print DES "if \(\-r \'$1\'\) \{\n";
        }
    }
    if ($l =~ /^elif (.+)/) {
        my $i = $1;
        $elif_flag = 1;
        # if test two var equal
        if ($i =~ /test ([a-zA-Z]*) = ([a-zA-Z]*)/){
            if ($if_print_flag eq 1 && $if_flag eq 1) {
                print DES "    } elsif \(\'$1\' eq \'$2\'\) \{\n";
                $elif_print_flag = 1;
            }
        }
    }
}

sub while_loop {
    my ($l) = @_;
    if ($l =~ /^while (.+)\n/) {
        # print $1;
        $while_loop = 1;
        if ($1 =~ /test (.+)/){
            # print $1;
            if ($1 =~ /(.*) -(eq|ne|lt|le|gt|ge) (.*)/) {
                print DES "while \($1 ";
                my $h = $2;
                my $y = $3;
                if ($h =~ /le/) {
                    print DES '<= ';
                } elsif ($h =~ /eq/) {
                    print DES '== ';
                }
                elsif ($h =~ /ne/) {
                    print DES '!= ';
                }
                elsif ($h =~ /lt/) {
                    print DES '< ';
                }
                elsif ($h =~ /gt/) {
                    print DES '> ';
                }
                elsif ($h =~ /ge/) {
                    print DES '>= ';
                }
                print DES "$y\) {\n";
            }
        }
    }
}

$for_flag = 0;
$if_flag = 0;
$if_print_flag = 0;
$elif_flag = 0;
$elif_print_flag = 0;
$while_loop = 0;
# $user_made_function_flag = 0;

for(my $i = 0; $i <= $#file_content; $i++) {
    first_line_env($file_content[$i]);
    copy_comments($file_content[$i]);
    $file_content[$i] = check_argument($file_content[$i]);
    copy_empty_line($file_content[$i]);

    # check for loop
    if ($file_content[$i] =~ /for (.+) in (.+)/) {
        $for_flag = 1;
        for_loop($file_content[$i]);
    }
    if ($file_content[$i] =~ /do\n/) {
        next;
    }
    if ($file_content[$i] =~ /done$|done\n/) {
        $for_flag = 0;
        print DES "}\n";
    }

    # check if condtion
    if ($file_content[$i] =~ /then\n/) {
        next;
    }
    if ($file_content[$i] =~ /else\n/) {
        if ($if_print_flag eq 1 && $elif_flag eq 0) {
            print DES "\} else \{\n";
        }
        if ($elif_print_flag eq 1 && $elif_flag eq 1) {
            print DES "    \} else \{\n";
        }   
    }
    if ($file_content[$i] =~ /fi\n/) {
        if ($if_print_flag eq 1 && $elif_flag eq 0) {
            print DES "\}\n";
        }
    }
    if ($file_content[$i] =~ /fi\n/) {
        if ($elif_print_flag eq 1 && $elif_flag eq 1) {
            print DES "    \}\n";
        }
    }

    read_function($file_content[$i]);
    echo_function($file_content[$i]);
    equal_n_dollar($file_content[$i]);
    system_function($file_content[$i]);
    cd_function($file_content[$i]);
    exit_function($file_content[$i]);
    if_condtion($file_content[$i]);
    while_loop($file_content[$i]);
    # user_made_function($file_content[$i]);
}

close (DES); 