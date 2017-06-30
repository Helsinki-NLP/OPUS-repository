#!/usr/bin/perl

print <<EOF;
<html>
<head>
<script type="text/javascript">
var prevLink = "";
function activate(e)
{
    if (prevLink) {
        document.getElementById(prevLink).className = "";
    }
    e.className = "active";
    prevLink = e.id;
}

function prime()
{
    var anchors = document.getElementsByTagName("a");
    for ( var i = 0, anchor; anchor = anchors[i]; i++ ) {
        anchor.onclick = function() {
            parent.frames[1].location =
                document.getElementById(
                    this.id.match('^cli:')
                        ? 'LetsMT'
                        : this.id.replace('(src)', '')
                ).href.replace( /\.html\$/, '.png' );
            return activate(this);
        };
        if ( parent.frames[2].location == anchor.href ) {
            activate(anchor);
        }
    }
}
window.onload = prime;
</script>
<link rel="stylesheet" href="pod.css" type="text/css" />
</head>
<body class="menu">
EOF


# trac-mirror for showing the source code
my $tracurl="http://opus.lingfil.uu.se/letsmt-trac/browser/letsmt_mirror/letsmt/trunk/dev/src/perllib/LetsMT";

print <<EOF;
<a target='main' id='LetsMT(src)' href='$tracurl/lib/LetsMT.pm'>(src)</a
    >&nbsp;<a id='LetsMT' target='main' href='LetsMT.html'>LetsMT</a><br/>
EOF

while (<>) {
    chomp;
    ########################################
    if ($_ =~ m/\.pm$/) {  # A module

        my $module = $_;
        $module =~ s/\//\::/g;
        $module =~ s/LetsMT:://g;
        $module =~ s/\.pm$//;

        my $graph = $_;
        $graph =~ s/\.pm/\.png/;

        my $page = $_;
        $page =~ s/\.pm$/\.html/;

        print <<EOF;
<a target='main' id='$module(src)' href='$tracurl/lib/$_'>(src)</a
    >&nbsp;&nbsp;&nbsp;<a id='$module' target='main' href='$page'>$module</a><br/>
EOF

    }
    ########################################
    elsif ($_ =~ m/\.t$/) {  # A test
        my $test = $_;
        $test =~ s/\.t$//;

        my $page = $_;
        $page =~ s/\.t$/\.html/;

        print <<EOF;
<a target='main' id='$test(src)' href='$tracurl/t/$_'>(src)</a
    >&nbsp;Test:&nbsp;<a id='$test' target='main' href='t/$page'>$test</a><br/>
EOF

    }
    ########################################
    else {  # A script

        my $page = $_;
        $page .= ".html";

        print <<EOF;
<a id='cli:$_(src)' target='main' href='$tracurl/bin/$_'>(src)</a
    >&nbsp;CLI:&nbsp;<a id='cli:$_' target='main' href='$page'>$_</a><br/>
EOF

    }
}


print '</body>
</html>
';
