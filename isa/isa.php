<?php

// unlink('corpora/2_fast_2_furious_dutger/joerg/config.inc');

/*
if (file_exists('include/config.isa')){
    include('include/config.isa');
}
else{
    include('include/config.inc');
}
*/
include('include/xmldoc.inc');
include('include/sentalign.inc');


session_start();
if (isset($_POST['newcorpus'])){
    session_destroy();
    session_start();
//    unset($_SESSION['corpus']);
//    $_POST['reset'] = 'reset';
}
    
if ($_POST['reset']){                      // reset button pressed -->
    if (isset($_SESSION['hardtag'])){      // destroy the session
	$hardtag = $_SESSION['hardtag'];   // but save the selected hard tag
    }
    if (isset($_SESSION['corpus'])){
	$corpus = $_SESSION['corpus'];
    }
    if (isset($_SESSION['user'])){
	$user = $_SESSION['user'];
    }
    session_destroy();
    session_start();
    if (isset($hardtag)){
	$_SESSION['hardtag']=$hardtag;
    }
    if (isset($corpus)){
	$_SESSION['corpus']=$corpus;
    }
    if (isset($user)){
	$_SESSION['user']=$user;
    }
}


$PHP_SELF = $_SERVER['PHP_SELF'];

// hard boundaries are stored in 
// $_SESSION['source_hard_ID'] and $_SESSION['target_hard_ID']
// (replace ID with valid sentence ID)
//
// hard boundary counters are in 
// $_SESSION['nr_source_hard'] and $_SESSION['nr_target_hard']

if (isset($_POST['corpus'])){
    $_SESSION['corpus'] = $_POST['corpus'];
}


@setlocale(LC_ALL,'en_US.utf8');
header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Interactive Sentence Alignment (ISA)</title>
<link rel="stylesheet" href="isa.css" type="text/css">
<meta http-equiv="Content-Type" content="text/html;charset=UTF-8" >
<?php include('include/java.inc'); ?>
</head>
<body>

<div class="title">
<h2><a href="index.php">ISA</a> / Interactive Sentence Alignment
<?php if (isset($_SESSION['corpus'])){echo " / ".$_SESSION['corpus'];} ?>
</h2>
</div>

<?php

if (isset($_SESSION['corpus'])){
    if (file_exists('corpora/'.$_SESSION['corpus'].'/config.inc')){
	include('corpora/'.$_SESSION['corpus'].'/config.inc');
    }
    elseif (file_exists('corpora/'.$_SESSION['corpus'].'/config.isa')){
	include('corpora/'.$_SESSION['corpus'].'/config.isa');
    }
    else{
	echo "<br /><br /><br /><h2 style=\"color:red\">Cannot find ISA configuration file for corpus '".$_SESSION['corpus']."'!</h2>";
	echo '<h3>Select a corpus:</h3><p>';
	select_corpus_form();
	echo '</p></body></html>';
	exit;
    }
}
else{
    echo '<br /><br /><br /><br /><h3>Select a corpus:</h3><p>';
    select_corpus_form();
    echo '</p></body></html>';
    exit;
}


// simple user management

if ($USER_MANAGEMENT){
    include('include/users.php');
    if (!logged_in()){
	exit;
    }
    if (isset($_SESSION['user'])){
	$dir = 'corpora/'.$_SESSION['corpus'].'/'.$_SESSION['user'];
	if (file_exists($dir.'/config.inc')){
	    include($dir.'/config.inc');
	    $BITEXT .= '.'.$_SESSION['user'];
	    $DATADIR .= '/'.$_SESSION['user'];
	}
    }
}

if (isset($_POST['alignprg'])){
  if (is_array($ALIGNPRGS)){
    if (array_key_exists($_POST['alignprg'],$ALIGNPRGS)){
       $ALIGN=$ALIGNPRGS[$_POST['alignprg']];
    }
  }
}


$srcbase = str_replace('.xml','',$SRCXML);
$trgbase = str_replace('.xml','',$TRGXML);

$src_sent_file = $srcbase . '.sent';    // sentences one per line
$trg_sent_file = $trgbase . '.sent';

$src_id_file = $srcbase . '.ids';     // sentence IDs one per line
$trg_id_file = $trgbase . '.ids';



if (isset($BITEXT)) $sentalign = $BITEXT;
else $sentalign = $srcbase.'-'.$trgbase.'.ces';


if (!file_exists($src_sent_file) ||
    (filemtime($SRCXML) > filemtime($src_sent_file))){
    doc2sent($SRCXML);
    $_SESSION['nr_source_hard'] = 0;
    read_tag_file($SRCXML,'source');
//    echo " nr hard boundaries: ".$_SESSION['nr_source_hard']."<br>";
}

if (! file_exists($trg_sent_file) ||
    (filemtime($TRGXML) > filemtime($trg_sent_file))){
    doc2sent($TRGXML);
    $_SESSION['nr_source_hard'] = 0;
    read_tag_file($TRGXML,'target');
//    echo " nr hard boundaries: ".$_SESSION['nr_target_hard']."<br>";
}

$src_ids = file($src_id_file);
$trg_ids = file($trg_id_file);

$src_ids = array_map("rtrim",$src_ids);
$trg_ids = array_map("rtrim",$trg_ids);

$src_idxs = array_flip($src_ids);
$trg_idxs = array_flip($trg_ids);


if ($_POST['evalnext']){
    $file = $sentalign.'.eval';
    count_eval($file);
    $total = $_SESSION['total_links'];
    echo '<div class="index">';
    echo 'nr ok: '.$_SESSION['ok_links'];
    printf(" (%6.2f) ",$_SESSION['ok_links']*100/$total);
    echo 'nr partially ok: '.$_SESSION['parts_links'];
    printf(" (%6.2f) ",$_SESSION['parts_links']*100/$total);
    echo 'nr wrong: '.$_SESSION['wrong_links'];
    printf(" (%6.2f) ",$_SESSION['wrong_links']*100/$total);
    echo 'do not know: '.$_SESSION['dontknow_links'];
    printf(" (%6.2f)",$_SESSION['dontknow_links']*100/$total);
    echo '</div>';
    $_REQUEST['next']=1;
}



//////////////////////////////////////////////////////////////////
// get some form data and set SESSION variables


if (!isset($_POST['reset'])){
    if (isset($_REQUEST['sadd'])){
	$idx = $_REQUEST['sadd'];
	if (isset($src_ids[$idx])){
	    if (! isset($_SESSION['source_hard_'.$src_ids[$idx]])){
		$_SESSION['source_hard_'.$src_ids[$idx]] = 1;
		$_SESSION['nr_source_hard']++;
		$new_src_boundary = $src_ids[$idx];
	    }
	}
    }
    if (isset($_REQUEST['srm'])){
	$idx = $_REQUEST['srm'];
	if (isset($src_ids[$idx])){
	    if (isset($_SESSION['source_hard_'.$src_ids[$idx]])){
		unset($_SESSION['source_hard_'.$src_ids[$idx]]);
		$_SESSION['nr_source_hard']--;
		$removed_src_boundary = $src_ids[$idx];
	    }
	    if ($_SESSION['src_start'] == $idx){
		$_SESSION['src_start']++;
	    }
	}
    }

    // sempty --> align ALL source sentences in this block to empty!
    //            (or take away the empty marker)
    if (isset($_REQUEST['sempty'])){
	$idx = $_REQUEST['sempty'];
	if (isset($src_ids[$idx])){
	    $unset=0;
	    if (isset($_SESSION['source_empty_'.$src_ids[$idx]])){
	      $unset=1;
	    }
	    $i=$idx;
	    while ($i>=0){
		// echo "empty source $src_ids[$i]<br />";
		if ($unset){unset($_SESSION['source_empty_'.$src_ids[$i]]);}
		else{$_SESSION['source_empty_'.$src_ids[$i]]=1;}
		if (isset($_SESSION['source_hard_'.$src_ids[$i]])){break;}
		$i--;
	    }
	    $i=$idx+1;
	    while ($i<count($src_ids)){
		if (isset($_SESSION['source_hard_'.$src_ids[$i]])){break;}
		// echo "empty source $src_ids[$i]<br />";
		if ($unset){unset($_SESSION['source_empty_'.$src_ids[$i]]);}
		else{$_SESSION['source_empty_'.$src_ids[$i]]=1;}
		$i++;
	    }
	}
    }

    if (isset($_REQUEST['tempty'])){
	$idx = $_REQUEST['tempty'];
	if (isset($trg_ids[$idx])){
	    $unset=0;
	    if (isset($_SESSION['target_empty_'.$trg_ids[$idx]])){
	      $unset=1;
	    }
	    $i=$idx;
	    while ($i>=0){
		// echo "empty target $trg_ids[$i]<br />";
		if ($unset){unset($_SESSION['target_empty_'.$trg_ids[$i]]);}
		else{$_SESSION['target_empty_'.$trg_ids[$i]]=1;}
		if (isset($_SESSION['target_hard_'.$trg_ids[$i]])){break;}
		$i--;
	    }
	    $i=$idx+1;
	    while ($i<count($trg_ids)){
		if (isset($_SESSION['target_hard_'.$trg_ids[$i]])){break;}
		// echo "empty target $trg_ids[$i]<br />";
		if ($unset){unset($_SESSION['target_empty_'.$trg_ids[$i]]);}
		else{$_SESSION['target_empty_'.$trg_ids[$i]]=1;}
		$i++;
	    }
	}
    }

    if (isset($_REQUEST['tadd'])){
	$idx = $_REQUEST['tadd'];
	if (isset($trg_ids[$idx])){
	    if (! isset($_SESSION['target_hard_'.$trg_ids[$idx]])){
		$_SESSION['target_hard_'.$trg_ids[$idx]] = 1;
		$_SESSION['nr_target_hard']++;
		$new_trg_boundary = $trg_ids[$idx];
	    }
	}
    }
    if (isset($_REQUEST['trm'])){
	$idx = $_REQUEST['trm'];
	if (isset($trg_ids[$idx])){
	    if (isset($_SESSION['target_hard_'.$trg_ids[$idx]])){
		unset($_SESSION['target_hard_'.$trg_ids[$idx]]);
		$_SESSION['nr_target_hard']--;
		$removed_trg_boundary = $trg_ids[$idx];
	    }
	    if ($_SESSION['trg_start'] == $idx){
		$_SESSION['trg_start']++;
	    }
	}
    }
}
if (isset($_REQUEST['hardtag'])){
    $oldhardtag = $_SESSION['hardtag'];
    $_SESSION['hardtag'] = $_REQUEST['hardtag'];
    if (isset($oldhardtag)){
	if ($oldhardtag != $_REQUEST['hardtag']){
	    if ($_REQUEST['hardtag'] == 'link'){
		read_links($sentalign);
	    }
	    else{
		read_tag_file($SRCXML,'source');
		read_tag_file($TRGXML,'target');
	    }
	    status('added '.$_SESSION['tag_source:'.$_REQUEST['hardtag']].' (source) and '.$_SESSION['tag_target:'.$_REQUEST['hardtag']].' (target) <'.$_REQUEST['hardtag'].'> tag boundaries!');
	}
    }
}

if (isset($_REQUEST['minlen']))
    $_SESSION['minlen'] = $_REQUEST['minlen'];
if (isset($_REQUEST['win']))
    $_SESSION['win'] = $_REQUEST['win'];


//////////////////////////////////////////////////////////////
// set some defaults ....

if (!isset($_SESSION['hardtag'])){
    $_SESSION['hardtag'] = get_best_hard_tag($SRCXML,$TRGXML,$sentalign);
    read_tag_file($SRCXML,'source');
    read_tag_file($TRGXML,'target');
    read_links($sentalign);
}
if (!isset($_SESSION['minlen'])){
    $_SESSION['minlen']=5;
}
if (!isset($_SESSION['win'])){
    $_SESSION['win']=10;
}


//////////////////////////////////////////////////////////////////////////

if (!isset($_SESSION['src_start'])) $_SESSION['src_start']=0;
if (!isset($_SESSION['trg_start'])) $_SESSION['trg_start']=0;
if (!isset($_SESSION['show_max'])) $_SESSION['show_max']=$SHOWMAX;

if (isset($_REQUEST['next'])){
    if (isset($_SESSION['src_end']) && isset($_SESSION['trg_end'])){
	if ($_POST['evalnext']){
	    while (!isset($_SESSION['source_hard_'.$src_ids[$_SESSION['src_end']]])){
		$_SESSION['src_end']++;
		if ($_SESSION['src_end'] > count($src_ids)){break;}
	    }
	    while (!isset($_SESSION['target_hard_'.$trg_ids[$_SESSION['trg_end']]])){
		$_SESSION['trg_end']++;
		if ($_SESSION['trg_end'] > count($trg_ids)){break;}
	    }
	}
	$_SESSION['src_start'] = $_SESSION['src_end'];
	$_SESSION['trg_start'] = $_SESSION['trg_end'];
    }
}
if (isset($_REQUEST['prev'])){
    if (isset($_SESSION['page'])){
	$page = $_SESSION['page']-1;
    }
    $srcend = $_SESSION['src_start'];
    $trgend = $_SESSION['trg_start'];
    list($_SESSION['src_start'],$_SESSION['trg_start']) = 
	get_prev_start($srcend,$trgend,$_SESSION['show_max']);
}
if (isset($_REQUEST['all'])){
    $_SESSION['src_start']=0;
    $_SESSION['trg_start']=0;
    $_SESSION['show_max'] = max(count($src_ids),count($trg_ids));
}
if (isset($_REQUEST['start'])){
    $_SESSION['src_start']=0;
    $_SESSION['trg_start']=0;
}
if (isset($_REQUEST['end'])){
    list($_SESSION['src_start'],$_SESSION['trg_start']) = 
	get_prev_start(count($src_ids)+1,count($trg_ids)+1,
		       $_SESSION['show_max']);
}


if (isset($_REQUEST['show'])){
    $_SESSION['show_max'] = $_REQUEST['show'];
}



if ($_POST['align']){
    sentence_align($src_sent_file,$trg_sent_file);
}
elseif ($_POST['save']){
    save_sentence_alignment($SRCXML,$TRGXML,$sentalign);
    status("bitext saved to ".$sentalign);
}
elseif ($_POST['mail'] && isset($_POST['email'])){
    if ($_POST['email'] != 'yourmail@host'){
	$_SESSION['email'] = $_POST['email'];
	$_SESSION['format'] = $_POST['format'];
	if (send_sentence_alignment($SRCXML,$TRGXML,
				    $sentalign,
				    $_POST['format'],
				    $_POST['email'])){
	    status("bitext sent to ".$_POST['email']);
	}
	else{
	    status("sending to ".$_POST['email'].' failed!');
	}
    }
}
elseif ($_POST['reset']){
    $_SESSION['nr_source_hard'] = 0;
    $_SESSION['nr_target_hard'] = 0;
    read_tag_file($SRCXML,'source');
    read_tag_file($TRGXML,'target');
    if ($_REQUEST['hardtag'] == 'link'){
	if (file_exists($sentalign)){
	    read_links($sentalign);
	}
    }
}
elseif ($_POST['cognates']){
    add_cognate_boundaries($src_sent_file,$trg_sent_file,
			   $_SESSION['src_start'],
			   $_SESSION['trg_start'],
			   $_SESSION['show_max'],
			   $_SESSION['win'],
			   $_SESSION['minlen']);
}




echo '<div class="alignform">';


###########################################################################

if ($ISA_MODE == 'eval'){
    echo "<br /><br /><form action=\"$PHP_SELF\" method=\"post\">";
    echo '<input type="submit" name="evalnext" value="save &amp; next">';
}

###########################################################################

else{
echo "<form action=\"$PHP_SELF\" method=\"post\">";

//echo '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
//echo '<br>';

echo '<select name="minlen">';
for ($i=1;$i<=10;$i++){
    echo '<option';
    if ($i == $_SESSION['minlen']){
	echo ' selected';
    }
    echo ' value="'.$i.'">&ge;'.$i.' char</option>';
}
echo '</select>';
echo '<select name="win">';
for ($i=1;$i<=10;$i++){
    echo '<option';
    if ($i == $_SESSION['win']){
	echo ' selected';
    }
    echo ' value="'.$i.'">&le;'.$i.' sentences</option>';
}
echo '</select>';
echo '<input type="submit" name="cognates" value="cognates">';

//echo '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
echo '<br>';

if (!$DISABLE_EMAIL){
    $formats = array('xces' => 'XCES Align',
		     'tmx' => 'TMX',
		     'text' => 'plain text');
    echo '<select name="format">';
    foreach ($formats as $format => $name){
	echo '<option ';
	if ($format == $_SESSION['format']){
	    echo 'selected ';
	}
	echo 'value="'.$format.'">'.$name.'</option>';
    }
    echo '</select>';
    if (isset($_SESSION['email'])){
	echo '<input name="email" value="'.$_SESSION['email'].'">';
    }
    else{
	echo '<input size="15" name="email" value="yourmail@host">';
    }
    echo '<input type="submit" name="mail" value="mail">';
//    echo '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
    echo '<br>';
}

$srctags = explode(' ',$_SESSION['tags_source']);
$trgtags = explode(' ',$_SESSION['tags_target']);
$structags = array_intersect($srctags,$trgtags);
if (file_exists($sentalign)){
    $structags[] = 'link';
}


echo '<input type="submit" name="newcorpus" value="change corpus">';
// select_corpus();
if (count($structags)>1){
    echo '<select onChange="JavaScript:submit()" name="hardtag">';
    foreach ($structags as $tag){
	if ($_SESSION['hardtag'] == $tag){
	    echo '<option selected value="'.$tag.'">'.$tag.'</option>';
	}
	else{
	    echo '<option value="'.$tag.'">'.$tag.'</option>';
	}
    }
    echo '</select>';
}
echo '<input type="submit" name="reset" value="reset">';

if (!$DISABLE_SAVE){
    echo '<input type="submit" name="save" value="save">';
}

if (is_array($ALIGNPRGS)){
   if (count($ALIGNPRGS)>1){
   echo '<select name="alignprg">';
   foreach ($ALIGNPRGS as $name => $command){
	if ($command == $ALIGN){
	  echo '<option selected value="'.$name.'">'.$name.'</option>';
	} else {
	  echo '<option value="'.$name.'">'.$name.'</option>';
	}
   }
   echo '</select>';
   }
}

echo '<input type="submit" name="align" value="align">';
echo '</form>';
echo '</div>';

echo '<div class="help"><a ';
echo "onMouseOver=\"return escape('";
echo '<ul><li>click on green highlighting: add boundary';
echo '<li>click on red highlighting: remove boundary';
echo '<li>cognates: add boundaries before sentence pairs containing identical words';
echo '<li>click on sentence IDs: add/remove empty links';
echo '<li>mail: send sentence alignments via e-mail';
echo '<li>reset: delete <b>all</b> boundaries in the <b>entire</b> document and restore initial boundaries';
echo '<li>save: save alignments on the server';
echo '<li>align: run the automatic sentence aligner</ul>';
echo 'click for more help ...';
echo "')\"";
echo ' href="doc/isa.html" target="_blank">Help?</a>';
}

echo '</div>';

show_bitext($src_sent_file,$trg_sent_file,
	    $_SESSION['src_start'],
	    $_SESSION['trg_start'],
	    $_SESSION['show_max']);


if ($ISA_MODE == 'eval'){
    echo '<div class="alignform">';
    echo '<input type="submit" name="evalnext" value="save &amp; next">';
    echo '</div></form>';
}


?>

<script language="JavaScript" type="text/javascript" src="include/wz_tooltip.js">

</script>
</body>
</html>
