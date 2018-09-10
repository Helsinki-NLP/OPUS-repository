<?php



if (isset($_POST['corpus'])){
    session_start() ;
    session_destroy();
    session_start() ;
    $_SESSION['corpus'] = $_POST['corpus'];
    if ($_POST['submit'] == 'start ICA'){
	header('Location: ica.php');
    }
    else{
	header('Location: isa.php');
    }
}

include('include/xmldoc.inc');

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>ISA: Interactive Alignment of Bitexts</title>
<link rel="stylesheet" href="isa.css" type="text/css">
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
<?php include('include/java.inc'); ?>
</head>
<body>


<table border="0" align="center" cellspacing="35">
<tr>



<td valign="top" width="50%">
<!--
<h3><a href="doc/isa.html">ISA: Interactive Sentence Alignment</a></h3>
-->

<div class="title">
<h2><a href="index.php">ISA</a> / Interactive Sentence Alignment</h2>
</div>
<br clear="all" />


ISA is a PHP based web interface for interactive sentence alignment of
parallel XML documents. It uses as the backend the length-based Gale&amp;Church
approach to sentence alignment but it can be used for manual alignment. The
basic idea is to use the interface for

<ul>
<li> adding hard boundaries to improve quality and performance of the automatic
alignment
<li> correcting existing alignments by removing/adding new segment boundaries
</ul>

The interface allows you to work only on small portions of the document or the
entire document. Alignment results can be saved (if not disabled) or sent via
e-mail (if not disabled) in various formats (XCES align with pointers to
external sentence IDs, plain text format or simple TMX).
</td>

<!--
<td valign="top">
<h3><a href="doc/ica.html">ICA: Interactive Clue Alignment</a></h3>

ICA is a PHP based web interface for interactive word alignment. It uses as its
backend the <a href="http://sourceforge.net/projects/uplug">Clue Aligner</a>
but can be used for manual alignment as well. You can

<ul>
<li>select clues and clue weights
<li>inspect alignment strategies and matching clues
<li>correct the alignment by adding and removing links
<li>display the contents of clue score databases
</ul>

ICA works on one sentence pair at a time taken from a pre-defined parallel
corpus (its location is hard-coded in the script for the time being). PHP is a
server side scripting language and, therefore, the corpus has to be located on
the server running the script. An upload function could easily be
integrated. However, we would then need some form of authentication for
protection. The
script also needs to have access to appropriate clues stored in local
(server-side) database files (one for each type). These files can be produced
by the Clue Aligner off-line.
</td>

</tr>
<tr>
-->

<td valign="top">
<h4>Select a corpus for sentence alignment:</h4><p>
<?php select_corpus_form(); ?>
</td>

<!--
<td valign="bottom">
<h4>Select a corpus for word alignment:</h4>
<?php select_corpus_form('ica'); ?>
</td>
-->

</tr>

</table>
</body>
</html>
