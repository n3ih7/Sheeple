#!/usr/bin/perl -w
foreach $c_file (glob("*.c")) {
    system "gcc -c $c_file";
}
