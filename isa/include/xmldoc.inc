<?php


$sent_id = null;
$out = null;            // global file output handler

function get_best_hard_tag($srcxml,$trgxml,$sentalign){

    read_tag_file($srcxml,'source');
    read_tag_file($trgxml,'target');

    if (file_exists($sentalign)){
	read_links($sentalign);
    }
    $srctags = explode(' ',$_SESSION['tags_source']);
    $trgtags = explode(' ',$_SESSION['tags_target']);
    $structags = array_intersect($srctags,$trgtags);
    if (file_exists($sentalign)){
	$structags[] = 'link';
    }
    $nr=0;
    $besttag='';
    foreach ($structags as $tag){

//	echo $_SESSION['tag_source:'.$tag].' - '.$_SESSION['tag_target:'.$tag]."<br>";
	if ($_SESSION['tag_source:'.$tag] == $_SESSION['tag_target:'.$tag]){
	    if ($_SESSION['tag_source:'.$tag]>$nr){
		$nr=$_SESSION['tag_source:'.$tag];
		$besttag=$tag;
	    }
	}
    }
    return $besttag;
}


function read_tag_file($xmlfile,$language){

//    echo "read $language ...<br>";

    $filebase = str_replace('.xml','',$xmlfile);
    $tag_file = $filebase . '.tags';

    if (!file_exists($tag_file)){
	doc2sent($xmlfile);
    }

    $struc_tag = array();

    if (file_exists($tag_file)){
	$lines = file($tag_file);
	$lines = array_map("rtrim",$lines);
	$first=true;
	foreach ($lines as $line){
	    $tags = explode(' ',$line);
	    $sid = array_pop($tags);
	    $tags = array_unique($tags);

	    foreach ($tags as $tag){
		$_SESSION['tag_'.$language.':'.$tag]++;
		$struc_tag[$tag] = 1;
		if (! $first){       // don't need a boundary before first line
		    if ($tag == $_SESSION['hardtag']){
			$_SESSION[$language.'_hard_'.$sid] = 1;
			$_SESSION['nr_'.$language.'_hard']++;
		    }
		}
	    }
	    $first=false;
	}
	$_SESSION['tags_'.$language]=implode(' ',array_keys($struc_tag));
    }
}


function doc2sent($xmlfile){

    global $sentFH;
    global $idFH;
    global $tagFH;

    $filebase = str_replace('.xml','',$xmlfile);
    $sentfile = $filebase . '.sent';    // sentences one per line
    $idfile = $filebase . '.ids';     // sentence IDs one per line
    $tagfile = $filebase . '.tags';       // all tags above sentence level

    $in = fopen($xmlfile,"r") or exit("unable to open $xmlfile!");
    $sentFH = fopen($sentfile,"w") or exit("unable to open $sentfile!");
    $idFH = fopen($idfile,"w") or exit("unable to open $idfile!");
    $tagFH = fopen($tagfile,"w") or exit("unable to open $tagfile!");

    $xml_parser = xml_parser_create();
    xml_parser_set_option($xml_parser, XML_OPTION_CASE_FOLDING, false);
    xml_set_element_handler($xml_parser, "startElement", "endElement");
    xml_set_character_data_handler($xml_parser, "characterData");

    while ($data = fread($in, 4096)) {
	if (!xml_parse($xml_parser, $data, feof($in))) {
	    die(sprintf("XML error: %s at line %d",
			xml_error_string(xml_get_error_code($xml_parser)),
			xml_get_current_line_number($xml_parser)));
	}
    }
    xml_parser_free($xml_parser);
    fclose($sentFH);
    fclose($idFH);
    fclose($tagFH);
    fclose($in);

    read_tag_file($xmlfile,$language);

    status("XML document converted to plain text ... ");
//    echo "done!<br>";

}




// xml parser handler functions


function startElement($parser, $name, $attrs)
{
    global $SENTTAG;         // sentence tag name
    global $sent_id;          // current sentence ID

    global $idFH;
    global $tagFH;


    global $GlobalData;
    $GlobalData='';

    // Save structure tags before each sentence tag
    // before checking the tag-name --> include sentence tags

    if ($sent_id == null){
	fwrite($tagFH,$name.' ');
    }

    if ($name == $SENTTAG){
	$sent_id = $attrs['id'];
	fwrite($idFH,$attrs['id']."\n");
	fwrite($tagFH,$attrs['id']."\n");
    }

    // after checking the tag-name --> don't include sentence tags

//    if ($sent_id == null){
//	fwrite($tagFH,$name.' ');
//    }

}



function endElement($parser, $name)
{
    global $SENTTAG;
    global $sent_id;
    global $sentFH;

    global $GlobalData;

    if (($sent_id != null) && ($GlobalData != "") && $name != $SENTTAG ){
       fwrite($sentFH,$GlobalData." ");
    }
    if ($name == $SENTTAG){
	fwrite($sentFH,"\n");
	$sent_id = null;
    }
}


function characterData($parser, $data)
{
    global $sent_id;
    global $sentFH;

    global $GlobalData;
    $GlobalData .= trim ($data);

    $data = rtrim($data);

//     if (($sent_id != null) && ($data != "")){
// //	fwrite($sentFH,utf8_decode($data)." ");
//        fwrite($sentFH,$data." ");
//     }

}



function status($message){
    echo '<div class="status">'.htmlentities($message).'</div>';
}




// make the id-file for sentence alignments (used by ICA)

$sidFH = null;

function make_id_file($xmlfile,$idfile){

    global $sidFH;

    $inFH = fopen($xmlfile,"r") or exit("unable to open $xmlfile!");
    $sidFH = fopen($idfile,"w") or exit("unable to open $idfile!");

//    status("create link ID file ...");

    $xml_parser = xml_parser_create();
    xml_parser_set_option($xml_parser, XML_OPTION_CASE_FOLDING, false);
    xml_set_element_handler($xml_parser, "IdStartElement","IdEndElement");

    while ($data = fread($inFH, 4096)) {
	if (!xml_parse($xml_parser, $data, feof($inFH))) {
	    die(sprintf("XML error: %s at line %d",
			xml_error_string(xml_get_error_code($xml_parser)),
			xml_get_current_line_number($xml_parser)));
	}
    }
    xml_parser_free($xml_parser);
    fclose($sidFH);
    fclose($inFH);
    status("link ID file created!");
}

// start a new XML tag: print id if it is a sentence link

function IdStartElement($parser, $name, $attrs)
{
    global $sidFH;
    global $SENTLINKTAG;

    if ($name == $SENTLINKTAG){
	list($src,$trg) = explode(';',$attrs['xtargets']);
	// skip x:0 sentence alignments!
	if (($src != "") && ($trg != "")){
	    fwrite($sidFH,$attrs['id']."\n");
	}
    }
}

// this function does nothing

function IdEndElement($parser, $name)
{
}



// make the id-file for sentence alignments (used by ICA)


function read_links($xmlfile){

    if (!file_exists($xmlfile)) return null;
    $inFH = fopen($xmlfile,"r") or exit("unable to open $xmlfile!");

    $_SESSION['read_links_time'] = time();
    $_SESSION['tag_source:link']=0;
    $_SESSION['tag_target:link']=0;

//    status("create link ID file ...");

    $xml_parser = xml_parser_create();
    xml_parser_set_option($xml_parser, XML_OPTION_CASE_FOLDING, false);
    xml_set_element_handler($xml_parser, "LinkStartElement","LinkEndElement");

    while ($data = fread($inFH, 4096)) {
	if (!xml_parse($xml_parser, $data, feof($inFH))) {
	    die(sprintf("XML error: %s at line %d",
			xml_error_string(xml_get_error_code($xml_parser)),
			xml_get_current_line_number($xml_parser)));
	}
    }
    xml_parser_free($xml_parser);
    fclose($inFH);

//    $_SESSION['tags_source'] .= ' link';
//    $_SESSION['tags_target'] .= ' link';
}

function notempty($var){
    return ($var != '');
}

// if tag = link --> save boundaries!

function LinkStartElement($parser, $name, $attrs)
{
    if ($name == 'link'){
	$link = $attrs['xtargets'];
//	echo '--'.$link.'--<br>';
	list($src,$trg) = explode(';',$link);
	$srcids = explode(' ',$src);
	$srcids = array_filter($srcids,"notempty");
	$trgids = explode(' ',$trg);
	$trgids = array_filter($trgids,"notempty");

	if (count($srcids)==0){
	    foreach ($trgids as $t){
		$_SESSION['target_empty_'.$t] = 1;
	    }
	    return true;
	}
	if (count($trgids)==0){
	    foreach ($srcids as $s){
		$_SESSION['source_empty_'.$s] = 1;
	    }
	    return true;
	}

	$firstsrc = $srcids[0];
	$firsttrg = $trgids[0];

	$lastsrc = array_pop($srcids);
	$lasttrg = array_pop($trgids);

//	$firstsrc = array_shift($srcids);
//	$firsttrg = array_shift($trgids);

	$_SESSION['tag_source:link']++;
	$_SESSION['tag_target:link']++;

	if ($_SESSION['hardtag'] == 'link'){
	    if (!isset($_SESSION['source_hard_'.$firstsrc])){
		$_SESSION['source_hard_'.$firstsrc] = 1;
		$_SESSION['nr_source_hard']++;
	    }
	    if (!isset($_SESSION['target_hard_'.$firsttrg])){
		$_SESSION['target_hard_'.$firsttrg] = 1;
		$_SESSION['nr_target_hard']++;
	    }
	    // add also hard boundaries after the sentence alignment
	    // (need this if we have incomplete sentence alignment files ...)
	    global $src_idxs,$src_ids;
	    $lastsrcidx=$src_idxs["$lastsrc"];

	    if (count($src_ids)>$lastsrcidx){
		$lastsrcidx++;
		$nextsrc=$src_ids[$lastsrcidx];

		if (!isset($_SESSION['source_hard_'.$nextsrc])){
		    $_SESSION['source_hard_'.$nextsrc] = 1;
		    $_SESSION['nr_source_hard']++;
		}
	    }
	    global $trg_idxs,$trg_ids;
	    $lasttrgidx=$trg_idxs[$lasttrg];
	    if (count($trg_ids)>$lasttrgidx){
		$lasttrgidx++;
		$nexttrg=$trg_ids[$lasttrgidx];
		if (!isset($_SESSION['target_hard_'.$nexttrg])){
		    $_SESSION['target_hard_'.$nexttrg] = 1;
		    $_SESSION['nr_target_hard']++;
		}
	    }
	}
    }
}

// this function does nothing

function LinkEndElement($parser, $name)
{
}


function select_corpus_form($type='isa'){
    $corpora = get_corpora();
    echo "<form action=\"".$_SERVER['PHP_SELF']."\" method=\"post\">";
    if (count($corpora)>20){
	select_corpus_pulldown($type);
    }
    else{
	select_corpus_radio($type);
    }
    if ($type == 'ica'){
	echo '<p><input type="submit" name="submit" value="start ICA"></p>';
    }
    else{
	echo '<p><input type="submit" name="submit" value="start ISA"></p>';
    }
    echo '</form>';
}


function select_corpus_radio($type='isa'){
    $corpora = get_corpora();
    foreach ($corpora as $corpus){
	if ($type=='isa' || file_exists('corpora/'.$corpus.'.ces')){
	    echo '<input type="radio" name="corpus" value="'.$corpus.'" ';
	    if (isset($_SESSION['corpus']) && $_SESSION['corpus']===$corpus){
		echo 'checked="1" ';
	    }
	    echo '/>'.$corpus.'<br/>';
	}
    }
}

function select_corpus_pulldown(){
    $corpora = get_corpora();
    echo '<select name="corpus">';
    foreach ($corpora as $corpus){
	if ($corpus === $_SESSION['corpus']){
	    echo '<option selected="1">'.$corpus.'</option>';
	}
	else{
	    echo '<option>'.$corpus.'</option>';
	}
	echo $corpus.'<br/>';
    }
    echo '</select>';
}


function select_corpus(){
    $corpora = get_corpora();
    echo '<select name="corpus" onchange="submit();">';
    foreach ($corpora as $corpus){
	if ($corpus === $_SESSION['corpus']){
	    echo '<option selected="1">'.$corpus.'</option>';
	}
	else{
	    echo '<option>'.$corpus.'</option>';
	}
	echo $corpus.'<br/>';
    }
    echo '</select>';
}

function get_corpora(){
    $corpora = array();
    if ($dh = opendir( 'corpora' ) ) {
	while ( ( $file = readdir( $dh ) ) !== false ) {
	    if ( $file !== '.' && $file !== '..' && $file !== 'CVS' ) {
		if (is_dir('corpora/'.$file)){
		    array_push($corpora,$file);
		    sort($corpora);
		}
	    }
	}
    }
    return $corpora;
}



?>
