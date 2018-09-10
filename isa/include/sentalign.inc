<?php


function add_cognate_boundaries($srcfile,$trgfile,$srcstart,$trgstart,$max,
				$window,$minlength){
    global $src_ids,$trg_ids;
    global $new_src_boundary,$new_trg_boundary;
    global $removed_src_boundary,$removed_trg_boundary;

    $src = fopen($srcfile,"r") or exit("unable to open $srcfile!");
    $trg = fopen($trgfile,"r") or exit("unable to open $trgfile!");

    $src_count=0;
    $trg_count=0;
    if (!isset($window)) $window=5;
    if (!isset($minlength)) $minlength=10;

    if ($srcstart>0){
	while ($buffer = fgets($src,4096)) {
	    $src_count++;
	    if ($src_count == $srcstart) break;
	}
    }
    if ($trgstart>0){
	while ($buffer = fgets($trg,4096)) {
	    $trg_count++;
	    if ($trg_count == $trgstart) break;
	}
    }

    $srcbuffer=array();
    $trgbuffer=array();

    while (($src_count-$srcstart) < $max && 
	   ($trg_count-$trgstart) < $max){

	while (count($srcbuffer)<$window*2){
	    if ($buffer = fgets($src,4096)){
		$srcbuffer[] = $buffer;
//		$src_count++;
	    }
	    else break;
	}
	while (count($trgbuffer)<$window*2){
	    if ($buffer = fgets($trg,4096)){
		$trgbuffer[] = $buffer;
//		$trg_count++;
	    }
	    else break;
	}

	$found_src=null;
	$found_trg=null;

	$j=0;
	while (($j < $window) || ($i-$j >= 0)){
	    for ($i=0;$i<$window;$i++){
		if (($i+$j) < $window){
//		    echo "compare ";
//		    echo $src_ids[$src_count+$i+1].' - ';
//		    echo $trg_ids[$trg_count+$i+$j+1].'<br>';
		    if (cognates($srcbuffer[$i],$trgbuffer[$i+$j],$minlength)){
			$found_src = $i+1;
			$found_trg = $i+$j+1;
			break;
		    }
		}
		if (($j>0) && (($i-$j) >= 0)){
//		    echo "compare ";
//		    echo $src_ids[$src_count+$i+1].' - ';
//		    echo $trg_ids[$trg_count+$i-$j+1].'<br>';
		    if (cognates($srcbuffer[$i],$trgbuffer[$i-$j],$minlength)){
			$found_src = $i+1;
			$found_trg = $i-$j+1;
			break;
		    }
		}
	    }
	    $j++;
	    if ($found_src != null) break;
	}
	if ($found_src != null){
//	    echo "found boundary: ";
//	    echo $src_ids[$src_count+$found_src].' - ';
//	    echo $trg_ids[$trg_count+$found_trg].'<br>';
	    global $highlight_word, $srcword, $trgword;
	    $sid = $src_ids[$src_count+$found_src-1];
	    if (!isset($_SESSION['source_hard_'.$sid])){
		$_SESSION['source_hard_'.$sid] = 1;
		$_SESSION['nr_source_hard']++;
		// echo "sid = $sid, found_src = $found_src, word = $srcword<br/";
		$highlight_word['src'][$sid]=$srcword;
	    }
	    $sid = $trg_ids[$trg_count+$found_trg-1];
	    if (!isset($_SESSION['target_hard_'.$sid])){
		$_SESSION['target_hard_'.$sid] = 1;
		$_SESSION['nr_target_hard']++;
		$highlight_word['trg'][$sid]=$trgword;
	    }
	    for ($i=0;$i<$found_src;$i++){
		array_shift($srcbuffer);
	    }
	    $src_count+=$found_src;
	    for ($i=0;$i<$found_trg;$i++){
		array_shift($trgbuffer);
	    }
	    $trg_count+=$found_trg;
	}
	else {
	    array_shift($srcbuffer);
	    array_shift($trgbuffer);
	    $src_count++;
	    $trg_count++;
	}
	if (($src_count-$srcstart)>$max*1.5) break;
	if (($trg_count-$trgstart)>$max*1.5) break;
    }
}

function cognates($src,$trg,$minlength){
    $srcwords = explode(' ',$src);
    $trgwords = explode(' ',$trg);
    global $srcword,$trgword;
    while (count($srcwords)){
	$srcword = array_shift($srcwords);
	if (strlen($srcword)<$minlength) continue;
	foreach ($trgwords as $trgword){
	    if (strlen($trgword)<$minlength) continue;
	    if ($srcword == $trgword) {
//		echo "found ... $srcword - $trgword<br>";
		return true;
	    }
	}
    }
    return false;
}


function ReadNextSegment($seg,&$fh,&$count,&$ids,&$sents,$max){
    $nr=0;
    while ($buffer = fgets($fh,4096)) {
	array_push($sents,$buffer);
	$count++;
	$nr++;
	if (isset($_SESSION[$seg.'_hard_'.$ids[$count]])){
	    return $nr;
//		echo '<tr><td>hard</td><td>'.$src_ids[$src_count].'</td></tr>';
	}

	if ($nr>$max*1.5) return $nr;
    }
}




function ShowSegment($prefix,$count,&$ids,&$sents){
    // prefix is the 'src' or 'trg' (for source or target side)

    global $highlight_word;       // for highlighting words
    global $PHP_SELF;
    global $ISA_MODE;

    $first = 1;
    $anchor = '';

    $pref = substr($prefix,0,1);
    if ($prefix == 'src'){
	global $new_src_boundary,$removed_src_boundary;
	$new_boundary = $new_src_boundary;
	$removed_boundary = $removed_src_boundary;
    }
    else{
	global $new_trg_boundary,$removed_src_boundary;
	$new_boundary = $new_trg_boundary;
	$removed_boundary = $removed_trg_boundary;
    }

    echo '<table width="100%" class="bitext-'.$prefix.'">';
    foreach ($sents as $sent){
	echo '<a name="'.$prefix.$ids[$count].'">';
	    if ($count>4){
		$anchor = '#'.$prefix.$ids[$count-4];
	    }
	    if ($first){
		echo "\n<tr
                onMouseOver=\"setStyle(this,'backgroundColor','#fcc')\" 
                onMouseOut=\"setStyle(this,'backgroundColor','white')\">";
		$id_field =  "<td width=\"10%\"
                onMouseOver=\"setStyle(this,'borderTop','2pt solid red')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?${pref}empty=$count$anchor'\">";
		$id_field.= $ids[$count].'</td>';
		$sent_field= "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid red')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?${pref}rm=$count$anchor'\"";
	    }
	    else{
		echo "\n<tr
                onMouseOver=\"setStyle(this,'backgroundColor','#cfc')\" 
                onMouseOut=\"setStyle(this,'backgroundColor','white')\">";
		$id_field = "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid #0a0')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?${pref}empty=$count$anchor'\">";
		$id_field .= $ids[$count].'</td>';
		$sent_field = "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid #0a0')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?${pref}add=$count$anchor'\"";
	    }
	    if (isset($new_boundary)){
		if (($new_boundary == $ids[$count]) ||
		    ($new_boundary == $ids[$count+1])){
		    $sent_field .= ' bgcolor="#FFCCCC"';
		}
	    }
	    if (isset($removed_boundary)){
		if (($removed_boundary == $ids[$count]) ||
		    ($removed_boundary == $ids[$count+1])){
		    $sent_field .= ' bgcolor="#CCFFCC"';
		}
	    }

	    if (isset($highlight_word[$prefix])){
		if (isset($highlight_word[$prefix][$ids[$count]])){
		    $sent = 
			str_replace($highlight_word[$prefix][$ids[$count]],
				    '<font style="background-color:#FFCCCC">'.
				    $highlight_word[$prefix][$ids[$count]].
				    '</font>',
				    $sent);
		    unset($highlight_word[$prefix][$ids[$count]]);
		}
	    }

	    $sent_field .= '>'.$sent.'</td>';

	    if ($prefix == 'src'){
		echo $id_field;
		echo $sent_field;
		echo '</tr>';
	    }
	    else{
		echo $sent_field;
		echo $id_field;
		echo '</tr>';
	    }


	    $first = 0;
	    $count++;
    }
    echo '</table>';
}



function show_bitext($srcfile,$trgfile,$srcstart,$trgstart,$max){
    global $src_ids,$trg_ids;
    global $new_src_boundary,$new_trg_boundary;
    global $removed_src_boundary,$removed_trg_boundary;
    global $PHP_SELF;
    global $ISA_MODE;

    $src = fopen($srcfile,"r") or exit("unable to open $srcfile!");
    $trg = fopen($trgfile,"r") or exit("unable to open $trgfile!");

    $src_count=0;
    $trg_count=0;

    if ($srcstart>0){
	while ($buffer = fgets($src,4096)) {
	    $src_count++;
	    if ($src_count == $srcstart) break;
	}
    }
    if ($trgstart>0){
	while ($buffer = fgets($trg,4096)) {
	    $trg_count++;
	    if ($trg_count == $trgstart) break;
	}
    }

    echo '<table class="bitext">';
    $continue=1;

    global $highlight_word;       // for highlighting words

    while ($continue){

	$first = 1;
	$anchor = '';

	echo '<tr><td width="50%">';

	$src_sents=array();
	$trg_sents=array();

	// if source & target are empty alignments OR
	//    target is not an empty alignment
	// --> show next source segment

	if ((isset($_SESSION['target_empty_'.$trg_ids[$trg_count]]) &&
	    isset($_SESSION['source_empty_'.$src_ids[$src_count-1]])) ||
	    (!isset($_SESSION['target_empty_'.$trg_ids[$trg_count]]))){

	    ReadNextSegment('source',$src,$src_count,$src_ids,$src_sents,$max);
	    $nr_src=count($src_sents);
	    ShowSegment('src',$src_count-$nr_src,$src_ids,$src_sents);
	}

	echo '</td><td>';

	// if source is not an empty alignment
	// --> show next target segment

	if (!isset($_SESSION['source_empty_'.$src_ids[$src_count-1]])){
	    ReadNextSegment('target',$trg,$trg_count,$trg_ids,$trg_sents,$max);
	    $nr_trg=count($trg_sents);
	    ShowSegment('trg',$trg_count-$nr_trg,$trg_ids,$trg_sents);
	}

	if (!count($src_sents) && !count($trg_sents)) $continue = 0;

	echo '</td>';
	if ($ISA_MODE == 'eval'){
	    if (isset($_SESSION['target_hard_'.$trg_ids[$trg_count]])){
		echo '<td width="120">';
		echo '<div class="eval">';
		echo '<input type="radio" value="ok" name="eval_';
		echo $src_count.'_'.$trg_count.'" />ok<br />';
		echo '<input type="radio" value="parts" name="eval_';
		echo $src_count.'_'.$trg_count.'" />partially&nbsp;ok<br />';
		echo '<input type="radio" value="wrong" name="eval_';
		echo $src_count.'_'.$trg_count.'" />wrong<br />';
		echo '<input type="radio" value="dontknow" name="eval_';
		echo $src_count.'_'.$trg_count.'" />don\'t&nbsp;know';
		echo '</div>';
		echo '</td>';
	    }
	}

	echo '</tr>';
	if (($src_count-$srcstart)>=$max||($trg_count-$trgstart)>=$max) break;
    }
    echo '</table>';

    fclose($src);
    fclose($trg);

//    echo "$src_count ... $trg_count<br>";

////////////////////////////////////////////////////////////////////
// navigation bar

    $_SESSION['src_end'] = $src_count;
    $_SESSION['trg_end'] = $trg_count;

    echo '<div class="index">';
    if (($_SESSION['src_start'] != 0 && $_SESSION['trg_start'] != 0) 
	&& ($ISA_MODE != 'eval')){
	echo '<a href="'.$PHP_SELF.'?start">&lt;&lt;</a> ';
	echo '<a href="'.$PHP_SELF.'?prev"> previous page</a> | ';
    }
    foreach (array(10,20,50,100,200) as $max){
	if (($ISA_MODE != 'eval')){
	    if ($_SESSION['show_max'] == $max){
		echo $max.' | ';
	    }
	    else{
		echo '<a href="'.$PHP_SELF.'?show='.$max.'">'.$max.'</a> | ';
	    }
	}
    }
    if (($src_count<count($src_ids)) || ($trg_count<count($trg_ids))){
	if ($ISA_MODE != 'eval'){
	    echo '<a href="'.$PHP_SELF.'?next">next page</a> ';
	    echo '<a href="'.$PHP_SELF.'?end">&gt;&gt;</a>';
	}
    }
    echo '</div>';

}





function show_bitext_old($srcfile,$trgfile,$srcstart,$trgstart,$max){
    global $src_ids,$trg_ids;
    global $new_src_boundary,$new_trg_boundary;
    global $removed_src_boundary,$removed_trg_boundary;
    global $PHP_SELF;
    global $ISA_MODE;

    $src = fopen($srcfile,"r") or exit("unable to open $srcfile!");
    $trg = fopen($trgfile,"r") or exit("unable to open $trgfile!");

    $src_count=0;
    $trg_count=0;

    if ($srcstart>0){
	while ($buffer = fgets($src,4096)) {
	    $src_count++;
	    if ($src_count == $srcstart) break;
	}
    }
    if ($trgstart>0){
	while ($buffer = fgets($trg,4096)) {
	    $trg_count++;
	    if ($trg_count == $trgstart) break;
	}
    }

    echo '<table class="bitext">';
    $continue=1;

    global $highlight_word;       // for highlighting words

    while ($continue){
	$continue = 0;

	$first = 1;
	$anchor = '';
	echo '<tr><td width="50%">';

//	if (isset($_SESSION['target_empty_'.$trg_ids[$trg_count]])){
//	    echo "empty target: $trg_count - don't display source<br>";
//	}

	// skip displaying source sentences if target sentences
	// are aligned to empty
	if (!isset($_SESSION['target_empty_'.$trg_ids[$trg_count]]) ||
	    isset($_SESSION['source_empty_'.$src_ids[$src_count]])){

	echo '<table width="100%" class="bitext-src">';
	while ($buffer = fgets($src,4096)) {
	    echo '<a name="src'.$src_ids[$src_count].'">';
	    if ($src_count>4){
		$anchor = '#src'.$src_ids[$src_count-4];
	    }
	    if ($first){
		echo "\n<tr
                onMouseOver=\"setStyle(this,'backgroundColor','#fcc')\" 
                onMouseOut=\"setStyle(this,'backgroundColor','white')\">";
		echo "<td width=\"10%\"
                onMouseOver=\"setStyle(this,'borderTop','2pt solid red')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?sempty=$src_count$anchor'\">";
		echo $src_ids[$src_count].'</td>';
		echo "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid red')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?srm=$src_count$anchor'\"";
	    }
	    else{
		echo "\n<tr
                onMouseOver=\"setStyle(this,'backgroundColor','#cfc')\" 
                onMouseOut=\"setStyle(this,'backgroundColor','white')\">";
		echo "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid #0a0')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?sempty=$src_count$anchor'\">";
		echo $src_ids[$src_count].'</td>';
		echo "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid #0a0')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?sadd=$src_count$anchor'\"";
	    }
	    if (isset($new_src_boundary)){
		if (($new_src_boundary == $src_ids[$src_count]) ||
		    ($new_src_boundary == $src_ids[$src_count+1])){
		    echo ' bgcolor="#FFCCCC"';
		}
	    }
	    if (isset($removed_src_boundary)){
		if (($removed_src_boundary == $src_ids[$src_count]) ||
		    ($removed_src_boundary == $src_ids[$src_count+1])){
		    echo ' bgcolor="#CCFFCC"';
		}
	    }

	    if (isset($highlight_word['src'])){
		if (isset($highlight_word['src'][$src_ids[$src_count]])){
		    $buffer = 
			str_replace($highlight_word['src'][$src_ids[$src_count]],
				    '<font style="background-color:#FFCCCC">'.
				    $highlight_word['src'][$src_ids[$src_count]].
				    '</font>',
				    $buffer);
		    unset($highlight_word['src'][$src_ids[$src_count]]);
		}
	    }

	    echo '>'.$buffer.'</td></tr>';


	    $first = 0;
	    $src_count++;
	    $continue++;
	    if (isset($_SESSION['source_hard_'.$src_ids[$src_count]])){
//		echo '<tr><td>hard</td><td>'.$src_ids[$src_count].'</td></tr>';
		break;
	    }
	    if (($src_count-$srcstart)>$max*1.5) break;
	}
	echo '</table>';
	}

	echo '</td><td>';


//	if (isset($_SESSION['source_empty_'.$src_ids[$src_count-1]])){
//	    echo "empty source: $src_count - don't display target<br>";
//	}

	// skip displaying target sentences if the previous source sentence
	// is aligned to empty
	if (!isset($_SESSION['source_empty_'.$src_ids[$src_count-1]])){

	$first = 1;
	$anchor = '';
	echo '<table width="100%" class="bitext-trg">';
	while ($buffer = fgets($trg,4096)) {
	    echo '<a name="trg'.$trg_ids[$trg_count].'">';
	    if ($trg_count>4){
		$anchor = '#trg'.$trg_ids[$trg_count-4];
	    }

	    // print the sentence

	    if ($first){
		echo "\n<tr
                onMouseOver=\"setStyle(this,'backgroundColor','#fcc')\" 
                onMouseOut=\"setStyle(this,'backgroundColor','white')\">";
		echo "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid red')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?trm=$trg_count$anchor'\"";
	    }
	    else{
		echo "\n<tr
                onMouseOver=\"setStyle(this,'backgroundColor','#cfc')\" 
                onMouseOut=\"setStyle(this,'backgroundColor','white')\">";
		echo "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid #0a0')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?tadd=$trg_count$anchor'\"";
	    }
	    if (isset($new_trg_boundary)){
		if (($new_trg_boundary == $trg_ids[$trg_count]) ||
		    ($new_trg_boundary == $trg_ids[$trg_count+1])){
		    echo ' bgcolor="#FFCCCC"';
		}
	    }
	    if (isset($removed_trg_boundary)){
		if (($removed_trg_boundary == $trg_ids[$trg_count]) ||
		    ($removed_trg_boundary == $trg_ids[$trg_count+1])){
		    echo ' bgcolor="#CCFFCC"';
		}
	    }

	    if (isset($highlight_word['trg'])){
		if (isset($highlight_word['trg'][$trg_ids[$trg_count]])){
		    $buffer = 
			str_replace($highlight_word['trg'][$trg_ids[$trg_count]],
				    '<font style="background-color:#FFCCCC">'.
				    $highlight_word['trg'][$trg_ids[$trg_count]].
				    '</font>',
				    $buffer);
		    unset($highlight_word['trg'][$trg_ids[$trg_count]]);
		}
	    }

	    echo '>'.$buffer.'</td>';

	    // print the sentence ID

	    if ($first){
		echo "<td width=\"10%\"
                onMouseOver=\"setStyle(this,'borderTop','2pt solid red')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?tempty=$trg_count$anchor'\">";
	    }
	    else{
		echo "<td
                onMouseOver=\"setStyle(this,'borderTop','2pt solid #0a0')\" 
                onMouseOut=\"setStyle(this,'borderTop','2pt solid white')\"
                onClick=\"window.location='$PHP_SELF?tempty=$trg_count$anchor'\">";
	    }
	    echo $trg_ids[$trg_count].'</td></tr>';


	    $first = 0;
	    $trg_count++;
	    $continue++;
	    if (isset($_SESSION['target_hard_'.$trg_ids[$trg_count]])){
//		echo '<tr><td>hard</td><td>'.$trg_ids[$trg_count].'</td></tr>';
		break;
	    }
	    if (($trg_count-$trgstart)>$max*1.5) break;
	}
	echo '</table>';
	}

	echo '</td>';
	if ($ISA_MODE == 'eval'){
	    if (isset($_SESSION['target_hard_'.$trg_ids[$trg_count]])){
		echo '<td width="120">';
		echo '<div class="eval">';
		echo '<input type="radio" value="ok" name="eval_';
		echo $src_count.'_'.$trg_count.'" />ok<br />';
		echo '<input type="radio" value="parts" name="eval_';
		echo $src_count.'_'.$trg_count.'" />partially&nbsp;ok<br />';
		echo '<input type="radio" value="wrong" name="eval_';
		echo $src_count.'_'.$trg_count.'" />wrong<br />';
		echo '<input type="radio" value="dontknow" name="eval_';
		echo $src_count.'_'.$trg_count.'" />don\'t&nbsp;know';
		echo '</div>';
		echo '</td>';
	    }
	}

	echo '</tr>';
	if (($src_count-$srcstart)>=$max||($trg_count-$trgstart)>=$max) break;
    }
    echo '</table>';

    fclose($src);
    fclose($trg);

////////////////////////////////////////////////////////////////////
// navigation bar

    $_SESSION['src_end'] = $src_count;
    $_SESSION['trg_end'] = $trg_count;

    echo '<div class="index">';
    if (($_SESSION['src_start'] != 0 && $_SESSION['trg_start'] != 0) 
	&& ($ISA_MODE != 'eval')){
	echo '<a href="'.$PHP_SELF.'?start">&lt;&lt;</a> ';
	echo '<a href="'.$PHP_SELF.'?prev"> previous page</a> | ';
    }
    foreach (array(10,20,50,100,200) as $max){
	if (($ISA_MODE != 'eval')){
	    if ($_SESSION['show_max'] == $max){
		echo $max.' | ';
	    }
	    else{
		echo '<a href="'.$PHP_SELF.'?show='.$max.'">'.$max.'</a> | ';
	    }
	}
    }
    if (($src_count<count($src_ids)) || ($trg_count<count($trg_ids))){
	if ($ISA_MODE != 'eval'){
	    echo '<a href="'.$PHP_SELF.'?next">next page</a> ';
	    echo '<a href="'.$PHP_SELF.'?end">&gt;&gt;</a>';
	}
    }
    echo '</div>';

}




function get_prev_start($srcend,$trgend,$max){

    $srccount=$srcend;
    $trgcount=$trgend;

    global $src_ids;
    global $trg_ids;

    while ($srcend-$srccount<$max && $trgend-$trgcount<$max){

	while ($srcend-$srccount<$max*1.2){
//	    echo "check $srccount<br/>";
	    $srccount--;
	    if (isset($_SESSION['source_hard_'.$src_ids[$srccount]])){
		if (!isset($_SESSION['source_empty_'.$src_ids[$srccount-1]])){
//		    echo "source break found at $srccount<br/>";
		    break;
		}
	    }
	    if ($srccount<0){
		$srccount=0;
		break;
	    }
	}
	while ($trgend-$trgcount<$max*1.2){
	    $trgcount--;
	    if (isset($_SESSION['target_hard_'.$trg_ids[$trgcount]])){
		if (!isset($_SESSION['target_empty_'.$trg_ids[$trgcount-1]])){
//		    echo "target break found at $trgcount<br/>";
		    break;
		}
	    }
	    if ($trgount<0){
		$trgcount=0;
		break;
	    }
	}
    }

//    echo "<br /><br /><br /><br /><br />start at $srcend:$trgend<br />";
//    echo "go to $srccount:$trgcount<br />";

    return array($srccount,$trgcount);
}



function read_next_segment(&$fh,&$text,$language){
    $read = '';
    $id = '';

    if (feof($fh)){return 0;}

    while ($buffer = fgets($fh,4096)) {
//	$buffer = utf8_decode($buffer);
	$buffer = rtrim($buffer);
	if ($buffer == '<hard>'){
	    if ($id != ''){
		$text[$id]=$read;
	    }
	    return 1;
	}
	if (substr($buffer,0,7) == '<s id="'){
	    if ($id != ''){
		$text[$id]=rtrim($read);
		$read = '';
	    }
	    list($before,$id,$after)=explode('"',$buffer);
	}
	else{
	    $read .= $buffer.' ';
	}
    }
	
    $text[$id]=rtrim($read);
    return 1;
}


function get_sent_align_pairs(&$pairs){

    global $src_ids,$trg_ids;

    $srcempty = array();
    $src = array();
    foreach ($src_ids as $id){
	if (count($src) == 0 || isset($_SESSION['source_hard_'.$id])){
	    $src[count($src)] = $id.' ';
	}
	else{
	    $src[count($src)-1] .= $id.' ';
	}
	if (isset($_SESSION['source_empty_'.$id])){
	    $srcempty[count($src)-1] = 1;
	}
    }
    $src = array_map("rtrim",$src);

    $trgempty = array();
    $trg = array();
    foreach ($trg_ids as $id){
	if (count($trg) == 0 || isset($_SESSION['target_hard_'.$id])){
	    $trg[count($trg)] = $id.' ';
	}
	else{
	    $trg[count($trg)-1] .= $id.' ';
	}
	if (isset($_SESSION['target_empty_'.$id])){
	  $trgempty[count($trg)-1] = 1;
	}
    }
    $trg = array_map("rtrim",$trg);

    $s=0;
    $t=0;
    while ($s<count($src) || $t<count($trg)){
	$idx = count($pairs);
	if ($srcempty[$s]){
	    $pairs[$idx]['src']=$src[$s];
	    $pairs[$idx]['trg']='';
	    $s++;
	}
	elseif ($trgempty[$t]){
	    $pairs[$idx]['trg']=$trg[$t];
	    $pairs[$idx]['src']='';
	    $t++;
	}
	else{
	    $pairs[$idx]['src']=$src[$s];
	    $pairs[$idx]['trg']=$trg[$t];
	    $s++;
	    $t++;
	}
    }
}



function save_sentence_alignment($srcdoc,$trgdoc,$aligndoc){

    $FH = fopen($aligndoc,"w") or exit("unable to open $aligndoc!");
    fwrite($FH,'<?xml version="1.0" encoding="utf-8"?>'."\n");
    fwrite($FH,'<!DOCTYPE cesAlign PUBLIC "-//CES//DTD XML cesAlign//EN" "">'."\n");
    fwrite($FH,'<cesAlign version="1.0" fromDoc="');
    fwrite($FH,$srcdoc.'" toDoc="'.$trgdoc."\">\n");
    fwrite($FH,'<linkGrp targType="s" fromDoc="');
    fwrite($FH,$srcdoc.'" toDoc="'.$trgdoc."\">\n");

    $pairs = array();
    get_sent_align_pairs($pairs);
    for ($i=0;$i<count($pairs);$i++){
	fwrite($FH,'<link id="SL'.$i.'" xtargets="');
	fwrite($FH,$pairs[$i]['src'].';'.$pairs[$i]['trg'].'" />'."\n");
    }

    fwrite($FH,"</linkGrp>\n</cesAlign>\n");
    fclose($FH);

}	




//////////////////////////////////////////////////////////////////////////
// send the sentence alignment vi e-mail


function send_sentence_alignment($srcdoc,$trgdoc,$aligndoc,$format,$email){

    global $src_ids,$trg_ids;
    global $MYNAME,$MYEMAIL;

    $subject = 'Interactive Clue Aligner';

    $body .= '========================================================'."\n";
    $body .= 'This message has been generated by '."\n";
    $body .= $_SERVER['HTTP_HOST'].$_SERVER['PHP_SELF']."\n";
    $body .= 'My apologies if you did not request this message,'."\n";
    $body .= '(somebody did type your e-mail address into the form)'."\n";
    $body .= '========================================================'."\n\n";

    if ($format == 'tmx'){
	$body .= sentence_align_tmx($srcdoc,$trgdoc,$aligndoc);
    }
    elseif ($format == 'text'){
	$body .= sentence_align_text($srcdoc,$trgdoc,$aligndoc);
    }
    else{
	$body .= sentence_align_xces($srcdoc,$trgdoc,$aligndoc);
    }

    $headers = "From: \"".$MYNAME."\" <".$MYEMAIL.">\n";

    if (mail($email, $subject, $body, $headers)) return true;
    return false;
}




//////////////////////////////////////////////////////////////////////////
// get the sentence alignments of the ENTIRE file in XCES align format
// (external pointers to source and target documents)

function sentence_align_xces($srcdoc,$trgdoc,$aligndoc){

    $string = '<?xml version="1.0" encoding="utf-8"?>'."\n";
    $string .='<!DOCTYPE cesAlign PUBLIC "-//CES//DTD XML cesAlign//EN" "">'."\n";
    $string .='<cesAlign version="1.0" fromDoc="';
    $string .=$srcdoc.'" toDoc="'.$trgdoc."\">\n";
    $string .='<linkGrp targType="s" fromDoc="';
    $string .=$srcdoc.'" toDoc="'.$trgdoc."\">\n";


    $pairs = array();
    get_sent_align_pairs($pairs);
    for ($i=0;$i<count($pairs);$i++){
	$string .='<link id="SL'.$i.'" xtargets="' ;
	$string .=$pairs[$i]['src'].';'.$pairs[$i]['trg'].'" />'."\n" ;
    }
    $string .="</linkGrp>\n</cesAlign>\n" ;
    return $string;
}




//////////////////////////////////////////////////////////////////////////
// get the sentence alignment in plain text file format
// (only the current part if SESSION variables are set)

function sentence_align_text($srcdoc,$trgdoc,$aligndoc){

    global $src_ids,$trg_ids;

    $srcbase = str_replace('.xml','',$srcdoc);
    $trgbase = str_replace('.xml','',$trgdoc);

    $srcfile = $srcbase . '.sent';
    $trgfile = $trgbase . '.sent';

    $src = fopen($srcfile,"r") or exit("unable to open $srcfile!");
    $trg = fopen($trgfile,"r") or exit("unable to open $trgfile!");

    if ($_SESSION['src_start']) $srcstart = $_SESSION['src_start'];
    else $srcstart = 0;
    if ($_SESSION['trg_start']) $trgstart = $_SESSION['trg_start'];
    else $trgstart = 0;
    if ($_SESSION['show_max']) $max = $_SESSION['show_max'];
    else $max = max(count($src_ids),count($trg_ids));

    $src_count=0;
    $trg_count=0;

    if ($srcstart>0){
	while ($buffer = fgets($src,4096)) {
	    $src_count++;
	    if ($src_count == $srcstart) break;
	}
    }
    if ($trgstart>0){
	while ($buffer = fgets($trg,4096)) {
	    $trg_count++;
	    if ($trg_count == $trgstart) break;
	}
    }

    $string = '';
    $continue=1;

    while ($continue){
	$continue = 0;

	$src_empty = false;
	if (!isset($_SESSION['target_empty_'.$trg_ids[$trg_count]])){
	    while ($buffer = fgets($src,4096)) {
		$string .= '(src) ['.$src_ids[$src_count].'] '.$buffer;
		if (isset($_SESSION['source_empty_'.$src_ids[$src_count]])){
		    $src_empty=true;
		}
		$src_count++;
		$continue++;
		if (isset($_SESSION['source_hard_'.$src_ids[$src_count]])){
		    break;
		}
		if (($src_count-$srcstart)>$max*1.5) break;
	    }
	}
	if (!$src_empty){
	    while ($buffer = fgets($trg,4096)) {
		$string .= '(trg) ['.$trg_ids[$trg_count].'] '.$buffer;
		$trg_count++;
		$continue++;
		if (isset($_SESSION['target_hard_'.$trg_ids[$trg_count]])){
		    break;
		}
		if (($trg_count-$trgstart)>$max*1.5) break;
	    }
	}
	if (($src_count-$srcstart)>=$max||($trg_count-$trgstart)>=$max) break;
	$string .= '---------------------------------------------------------------------------'."\n";
    }
    fclose($src);
    fclose($trg);

    return $string;
}


//////////////////////////////////////////////////////////////////////////
// get the sentence alignment of the current part of the bitext
// in simple TMX format

function sentence_align_tmx($srcdoc,$trgdoc,$aligndoc){

    global $src_ids,$trg_ids;
    global $LANGPAIR;

    $srclang = substr($LANGPAIR,0,2);
    $trglang = substr($LANGPAIR,2,2);

    $srcbase = str_replace('.xml','',$srcdoc);
    $trgbase = str_replace('.xml','',$trgdoc);

    $srcfile = $srcbase . '.sent';
    $trgfile = $trgbase . '.sent';

    $src = fopen($srcfile,"r") or exit("unable to open $srcfile!");
    $trg = fopen($trgfile,"r") or exit("unable to open $trgfile!");

    if ($_SESSION['src_start']) $srcstart = $_SESSION['src_start'];
    else $srcstart = 0;
    if ($_SESSION['trg_start']) $trgstart = $_SESSION['trg_start'];
    else $trgstart = 0;
    if ($_SESSION['show_max']) $max = $_SESSION['show_max'];
    else $max = max(count($src_ids),count($trg_ids));

    $src_count=0;
    $trg_count=0;

    if ($srcstart>0){
	while ($buffer = fgets($src,4096)) {
	    $src_count++;
	    if ($src_count == $srcstart) break;
	}
    }
    if ($trgstart>0){
	while ($buffer = fgets($trg,4096)) {
	    $trg_count++;
	    if ($trg_count == $trgstart) break;
	}
    }

    $time=date('YmdHi',time());
    $string = '<?xml version="1.0" encoding="UTF-8" ?>'."\n";
    $string .= '<tmx version="1.4">'."\n";
    $string .= '  <header creationdate="'.$time.'"'."\n";
    $string .= '          creationtool="Interactive Clue Aligner (ICA)"'."\n";
    $string .= '          datatype="unknown" />'."\n";
    $string .= '  <body>'."\n";


    $continue=1;
    while ($continue){
	$continue = 0;
	$string .= '    <tu changedate="'.$time.'">'."\n";

	$src_empty = false;
	if (!isset($_SESSION['target_empty_'.$trg_ids[$trg_count]])){

	    $string .= '      <tuv xml:lang="'.$srclang.'">';
	    while ($buffer = fgets($src,4096)) {
		$buffer = rtrim($buffer);
		$string .= "\n        ";
		$string .= '<seg id="SRC'.$src_ids[$src_count].'">';
		$string .= utf8_encode($buffer).'</seg>';
		if (isset($_SESSION['source_empty_'.$src_ids[$src_count]])){
		    $src_empty=true;
		}
		$src_count++;
		$continue++;
		if (isset($_SESSION['source_hard_'.$src_ids[$src_count]])){
		    break;
		}
		if (($src_count-$srcstart)>$max*1.5) break;
	    }
	    $string .= "\n      </tuv>\n";
	}

	if (!$src_empty){
	    $string .= '      <tuv xml:lang="'.$trglang.'">';
	    while ($buffer = fgets($trg,4096)) {
		$buffer = rtrim($buffer);
		$string .= "\n        ";
		$string .= '<seg id="TRG'.$trg_ids[$trg_count].'">';
		$string .= utf8_encode($buffer).'</seg>';
		$trg_count++;
		$continue++;
		if (isset($_SESSION['target_hard_'.$trg_ids[$trg_count]])){
		    break;
		}
		if (($trg_count-$trgstart)>$max*1.5) break;
	    }
	    $string .= "\n      </tuv>\n";
	}
	$string .= '    </tu>'."\n";
	if (($src_count-$srcstart)>=$max||($trg_count-$trgstart)>=$max) break;
    }
    fclose($src);
    fclose($trg);

    $string .= '  </body>'."\n";
    $string .= '</tmx>'."\n";

    return $string;
}



function get_all_boundaries(&$SrcHard,&$TrgHard){

    global $src_ids,$trg_ids;

    $nrSrcHard = $_SESSION['nr_source_hard'];
    $nrTrgHard = $_SESSION['nr_target_hard'];

    $count=0;
    $idx=0;
    while ($count<$nrSrcHard){
	if (! isset($src_ids[$idx])) break;
	if (isset($_SESSION['source_hard_'.$src_ids[$idx]])){
	    //echo "found src $src_ids[$idx]<br />";
	    array_push($SrcHard,$src_ids[$idx]);
	    $count++;
	}
	$idx++;
    }

    $count=0;
    $idx=0;
    while ($count<$nrTrgHard){
	if (! isset($trg_ids[$idx])) break;
	if (isset($_SESSION['target_hard_'.$trg_ids[$idx]])){
	    //echo "found trg $trg_ids[$idx]<br />";
	    array_push($TrgHard,$trg_ids[$idx]);
	    $count++;
	}
	$idx++;
    }	
}

/////////////////////////////////////////////////////////////////////////////


function sentence_align($srcfile,$trgfile){

    global $ALIGN;

    $srcbase = str_replace('.sent','',$srcfile);
    $trgbase = str_replace('.sent','',$trgfile);

    $srctokfile = $srcbase . '.tok';
    $trgtokfile = $trgbase . '.tok';

    $program = basename($ALIGN);

    if (substr($program,0,11) == 'srtalign.pl'){

	$SrcHard=array();
	$TrgHard=array();
	get_all_boundaries($SrcHard,$TrgHard);
	if (count($TrgHard)<count($SrcHard)){
	    $min = count($TrgHard);
	} else{
	    $min = count($SrcHard);
	}
	$bound=array();
	for ($i=0;$i<$min;$i++){
	    array_push($bound,$SrcHard[$i].':'.$TrgHard[$i]);
	}
	global $SRCXML,$TRGXML, $sentalign;

	$command = $ALIGN;
	if (count($bound)){
	    $command .= ' -h '.implode('+',$bound);
	}
	$command .= ' '.$SRCXML;
	$command .= ' '.$TRGXML;
	$command .= ' -v > '.$sentalign;
	$command .= " 2> $sentalign.tmp";

	// for OS X with fink ....
	// $command = 'test -r /sw/bin/init.sh && . /sw/bin/init.sh;'.$command;

	exec('ulimit -t 10;'.$command,$output,$return);

	$info = 'srt-align';
	if (count($bound)){
	    $info .= 'with fixpoints at ';
	    $info .= implode(', ',$bound);
	}
	$log = file_get_contents("$sentalign.tmp");
        echo '<div class="log"><pre>'.$log.'</pre></div>';
//	status($info);
	// status($command);

	// read sentence alignment from file!
	$_SESSION['hardtag'] = 'link';
	read_links($sentalign);
    }
    elseif ($program == 'align2'){
	make_align2_input($srcfile,$trgfile,
			  $srctokfile,$trgtokfile,
			  $_SESSION['src_start'],
			  $_SESSION['trg_start'],
			  $_SESSION['show_max']);

	$command = $ALIGN.' -v -D "<hard>" -d "<soft>"';
	$command .= ' '.$srctokfile.' '.$trgtokfile;
	$command .= ' > /dev/null 2>&1';
	// status("aligning input files ... $command");
	status("aligning input files ...");

	exec('ulimit -t 5;'.$command,$output,$return);

	parse_align2_result($srctokfile.'.al','source');
	parse_align2_result($trgtokfile.'.al','target');

	if (file_exists($srctokfile)) unlink($srctokfile);
	if (file_exists($trgtokfile)) unlink($trgtokfile);
	if (file_exists($srctokfile.'.al')) unlink($srctokfile.'.al');
	if (file_exists($trgtokfile.'.al')) unlink($trgtokfile.'.al');
	status("input files aligned (if ulimit of 5 seconds not exceeded)!");
    }
    else{
	global $SRCXML,$TRGXML, $sentalign;

	$command = $ALIGN;
	$command .= ' -src '.$SRCXML;
	$command .= ' -trg '.$TRGXML;
	$command .= ' > '.$sentalign;
	$tmpout = $sentalign.'.tmp';
	$command .= ' 2> '.$tmpout;

	// for OS X with fink ....
	// $command = 'test -r /sw/bin/init.sh && . /sw/bin/init.sh;'.$command;

	exec('ulimit -t 10;'.$command,$output,$return);

	$log = file_get_contents($tmpout);
	echo '<div class="log"><pre>'.$log.'</pre></div>';
	// status($command);

	// read sentence alignment from file!
	$_SESSION['hardtag'] = 'link';
	read_links($sentalign);
    }
}


function parse_align2_result($file,$language){

    $FH = fopen($file,"r") or exit("unable to open $file!");
    $sid = null;
    $score = null;
    $soft_found = false;

    while ($buffer = fgets($FH,4096)) {
	if (substr($buffer,0,6) == '.Score'){
	    list($before,$score) = explode(' ',$buffer);
	    //echo "found score $score<br>";
	}
	elseif (substr($buffer,0,7) == '<s id="'){
	    list($before,$sid,$after) = explode('"',$buffer);
	    //echo "found sid $sid<br>";
	    if ($soft_found){
		if (!isset($_SESSION[$language.'_hard_'.$sid])){
		    //echo "set boundary before $sid<br>";
		    $_SESSION[$language.'_hard_'.$sid] = 1;
		    $_SESSION[$language.'_score_'.$sid] = $score;
		    $_SESSION['nr_'.$language.'_hard']++;
		}
	    }
	    $soft_found = false;
	}
	elseif (substr($buffer,0,6) == '<soft>'){
	    //echo "found soft boundary<br>";
	    $soft_found = true;
	}
    }
    fclose($FH);
}


function make_align2_input($srcin,$trgin,$srcout,$trgout,
			  $srcstart,$trgstart,$max){

    global $src_ids,$trg_ids;

    $nrHard = $_SESSION['nr_source_hard'];       // nr hard boundaries
    if ($_SESSION['nr_target_hard']<$nrHard){    // (take minimum
	$nrHard = $_SESSION['nr_target_hard'];
    }

    $srcInFH = fopen($srcin,"r") or exit("unable to open $srcin!");
    $trgInFH = fopen($trgin,"r") or exit("unable to open $trgin!");

    $srcOutFH = fopen($srcout,"w") or exit("unable to open $srcout!");
    $trgOutFH = fopen($trgout,"w") or exit("unable to open $trgout!");

    $src_count=0;
    $trg_count=0;

    $src_CountHard=0;
    $trg_CountHard=0;

    if ($srcstart>0){
	while ($buffer = fgets($srcInFH,4096)) {
	    $src_count++;
	    if ($src_count == $srcstart) break;
	}
    }
    if ($trgstart>0){
	while ($buffer = fgets($trgInFH,4096)) {
	    $trg_count++;
	    if ($trg_count == $trgstart) break;
	}
    }

    fwrite($srcOutFH,'<hard>'."\n");
    fwrite($trgOutFH,'<hard>'."\n");

    $continue=1;
    while ($continue){
	$continue = 0;

	$first = 1;
	while ($buffer = fgets($srcInFH,4096)) {
	    fwrite($srcOutFH,'<s id="'.$src_ids[$src_count].'">'."\n");
	    $buffer = rtrim($buffer);
	    $buffer = str_replace(' ',"\n",$buffer);
	    fwrite($srcOutFH,$buffer."\n");
	    fwrite($srcOutFH,'<soft>'."\n");
	    $src_count++;
	    $continue++;
	    if (($src_countHard<$nrHard) &&
		(isset($_SESSION['source_hard_'.$src_ids[$src_count]]))){
		fwrite($srcOutFH,'<hard>'."\n");
		$src_countHard++;
		break;
	    }
	    if (($src_count-$srcstart)>$max*1.5) break;
	}


	$first = 1;
	while ($buffer = fgets($trgInFH,4096)) {
	    fwrite($trgOutFH,'<s id="'.$trg_ids[$trg_count].'">'."\n");
	    $buffer = rtrim($buffer);
	    $buffer = str_replace(' ',"\n",$buffer);
	    fwrite($trgOutFH,$buffer."\n");
	    fwrite($trgOutFH,'<soft>'."\n");
	    $trg_count++;
	    $continue++;
	    if (($trg_countHard<$nrHard) &&
		(isset($_SESSION['target_hard_'.$trg_ids[$trg_count]]))){
		fwrite($trgOutFH,'<hard>'."\n");
		$trg_countHard++;
		break;
	    }
	    if (($trg_count-$trgstart)>$max*1.5) break;
	}

	if (($src_count-$srcstart)>$max || ($trg_count-$trgstart)>$max) break;
    }

    fwrite($srcOutFH,"<hard>\n");
    fwrite($trgOutFH,"<hard>\n");
    fclose($srcOutFH);
    fclose($trgOutFH);
    fclose($srcInFH);
    fclose($trgInFH);

}

function count_eval($file){

    $fh = fopen($file,"a") or exit("unable to open $file!");

    foreach ($_POST as $key => $val){
	if (substr($key,0,5) == 'eval_'){
	    fwrite($fh,$key."\t".$val."\n");
	    if ($val == 'ok'){
		$_SESSION['ok_links']++;
	    }
	    if ($val == 'wrong'){
		$_SESSION['wrong_links']++;
	    }
	    if ($val == 'parts'){
		$_SESSION['parts_links']++;
	    }
	    if ($val == 'dontknow'){
		$_SESSION['dontknow_links']++;
	    }
	    $_SESSION['total_links']++;
	}
    }
    fclose($fh);
}





?>