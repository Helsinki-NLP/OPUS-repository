<?php


function WeightSelectionBoxOld($name,$selected){
    echo "<select name=\"$name\">";
    for ($i=0.01;$i<1;$i+=0.03){
//	if ($i == $selected){
	if ($i < ($selected+0.005) && ($i > $selected-0.005)){
	    echo "<option selected>$i</option>";
	}
	else{
	    echo "<option>$i</option>";
	}
    }
    echo '</select>';
}

function WeightSelectionBox($name,$selected,$start,$end,$steps){
    echo "<select name=\"$name\">";
    for ($i=$start;$i<=$end;$i+=$steps){
//	if ($i == $selected){
	if ($i < ($selected+$steps/2) && ($i > $selected-$steps/2)){
	    echo "<option selected>$i</option>";
	}
	else{
	    echo "<option>$i</option>";
	}
    }
    echo '</select>';
}


function SearchSelectionBox($selected){
    if (!isset($selected)) $selected='best_first -adj';
    echo "<select name=\"search\">";
    $methods = array('none','src','trg','union','intersection',
		'refined','competitive','best_first','best_first -adj');
    foreach ($methods as $method){
	if ($selected == $method){
	    echo "<option selected>$method</option>";
	}
	else{
	    echo "<option>$method</option>";
	}
    }
    echo '</select>'."\n";
}



//// make form

function AlignForm(){

    global $CLUES;
    global $IDS;

    echo "<form action=\"$PHP_SELF\" method=\"post\">";

    $existing_clues = array();
    $nr_selected = 0;
    foreach ($CLUES as $clue => $file){
	if (file_exists($file)){
	    $existing_clues[] = $clue;
	    if ($_SESSION[$clue]) $nr_selected++;
	}
    }
    $clues_per_column = round(count($existing_clues)/6);
    $_SESSION['available_clues']=$existing_clues;

    $count = 0;
    echo '<table><tr>';

    foreach ($existing_clues as $clue){

//	    if (($count == 0) || !($count % 10)){
	    if (($count == 0) || !($count % $clues_per_column)){
		if ($count){
		    echo '</td></tr></table></td>';
		}
		echo '<td valign="top">';
		echo '<table cellpadding="0" cellspacing="0">';
		echo '<tr><th>clue</th><th>weight</th></tr>';
	    }
	    echo '<tr><td>';

	    if ($_SESSION[$clue] || ($nr_selected == 0)){
		echo "<input type=\"checkbox\" checked name=\"$clue\" value=\"1\">";
	    }
	    else{
		echo "<input type=\"checkbox\" name=\"$clue\" value=\"1\">";
	    }
	    echo "<a href=\"$PHP_SELF?showdbm=".$clue.'">';
	    echo $clue;
	    echo '</a>&nbsp;&nbsp;';
	    echo '</td><td>';
	    WeightSelectionBox($clue.'_w',$_SESSION[$clue.'_w'],0.01,1,0.03);
	    echo '</td></tr>'."\n";
	    $count++;
    }
    echo '</td></tr></table></td>';
    echo '</tr></table><br>';


    $prev_selected;
    $next_selected;

    echo '<select name="id">';
    foreach ($IDS as $id){
	$id = rtrim($id);
	if ($selected) $next_selected = $id;
	$selected = 0;
	if (isset($_SESSION['id']) && ($_SESSION['id'] == $id)){
	    echo "<option selected>$id</option>\n";
	    $selected = 1;
	    if (isset($prev)) $prev_selected = $prev;
	}
	else{
	    echo "<option>$id</option>\n";
	}
	$prev = $id;
    }
    echo '</select>';

    echo SearchSelectionBox($_SESSION['search']);
    echo WeightSelectionBox('minscore',$_SESSION['minscore'],0,0.5,0.001);

    echo '<input type="submit" name="align" value="align">';
    global $DATADIR;
    $filename = $DATADIR.'/'.$_SESSION['id'];
    if (file_exists($filename)){
	echo '<input type="submit" name="read" value="read">';
    }
    global $DISABLE_SAVE;
    if (!$DISABLE_SAVE){
	echo '<input type="submit" name="save" value="save">';
    }
    echo '<input type="submit" name="newcorpus" value="change corpus">';
    if (isset($next_selected)){
	if (!$DISABLE_SAVE){
	    echo ' [ <a href="'.$PHP_SELF.'?save=save&align=align&id='.$next_selected.'">';
	    echo ' save &amp; align next </a> ] ';
	}
	echo ' [ <a href="'.$PHP_SELF.'?align=align&id='.$next_selected.'">';
	echo ' align next </a> ] ';

    }
    if (isset($prev_selected)){
	echo ' [ <a href="'.$PHP_SELF.'?align=align&id='.$prev_selected.'">';
	echo ' align previous </a> ] ';
    }
    echo '</form>';
}






function clear_session(){
    if (isset($_SESSION['nrSrc']) && isset($_SESSION['nrTrg'])){
	for ($i=0;$i<=$_SESSION['nrSrc'];$i++){
	    for ($j=0;$j<=$_SESSION['nrTrg'];$j++){
		if (isset($_SESSION['matrix:'.$i.':'.$j])) 
		    unset($_SESSION['matrix:'.$i.':'.$j]);
		if (isset($_SESSION['clues:'.$i.':'.$j])) 
		    unset($_SESSION['clues:'.$i.':'.$j]);
		if (isset($_SESSION['link:'.$i.':'.$j])) {
		    unset($_SESSION['link:'.$i.':'.$j]);
		    unset($_SESSION['inLink:'.$i.':'.$j]);
		}
	    }
	    if (isset($_SESSION['srcID:'.$i])) unset($_SESSION['srcID:'.$i]);
	    if (isset($_SESSION['srcToken:'.$j])) 
		unset($_SESSION['srcToken:'.$j]);
	}
	for ($j=0;$j<=$_SESSION['nrTrg'];$j++){
	    if (isset($_SESSION['trgID:'.$j])) unset($_SESSION['trgID:'.$j]);
	    if (isset($_SESSION['trgToken:'.$j])) 
		unset($_SESSION['trgToken:'.$j]);
	}
	unset($_SESSION['nrSrc']);
	unset($_SESSION['nrTrg']);

	$_SESSION['lowestScore'] = null;
	$_SESSION['highestScore'] = null;
    }
    $count=0;
    while (isset($_SESSION['alignLex:'.$count])){
	unset($_SESSION['alignLex:'.$count]);
	unset($_SESSION['alignXtrg:'.$count]);
	unset($_SESSION['alignScore:'.$count]);
	$count++;
    }

}


?>