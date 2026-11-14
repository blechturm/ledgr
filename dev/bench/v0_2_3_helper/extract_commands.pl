while (<>) {
  while (/"command":"((?:[^"\\]|\\.)*)"/g) {
    my $c = $1;
    next unless $c =~ /(runner\.R.*cut17-helper-1|measure_helper\.R --mode|fmatch_compare\.R --out|lean_helper_compare\.R --base-lib|lean_helper_insitu\.R --lib|collapse_semantics\.R --out|protocol_refusals\.R --record|oracle_check\.R --pin-lib)/;
    $c =~ s/\\n/\n/g; $c =~ s/\\"/"/g; $c =~ s/\\\\/\\/g;
    print "----\n$c\n";
  }
}
