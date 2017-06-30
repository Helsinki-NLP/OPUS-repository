#!/usr/bin/perl


my $module = shift(@ARGV);
my $output = shift(@ARGV);

# make sure output will exist
system("echo 'digraph G {\"$module\" [shape=box]; }' | dot -Tpng -o $output");


eval "require ($module)";

# more modules to be loaded?
foreach (@ARGV){
    eval "require $_";
}

require Class::Sniff;


my @sniffs = Class::Sniff->new_from_namespace({namespace => $module,
					      ignore => qr/^Exporter/});

my $sniff = pop @sniffs || exit 0;
my $graph = $sniff->combine_graphs(@sniffs);


if ($output=~/\.html/){
    open F,">$output";
    binmode F,":utf8";
    print F $graph->as_boxart_html_file();
    close F;
}
elsif ($output=~/\.png/){
    open F, "|dot -Tpng -o $output";
    print F $graph->as_graphviz();
    close F;
}
elsif ($output=~/\.svg/){
    open F, "|dot -Tsvg -o $output";
    print F $graph->as_graphviz();
    close F;
}
