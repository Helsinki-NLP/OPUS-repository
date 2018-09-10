<?php


function print_alignments(){
    $count=0;

    if (!isset($_SESSION['alignLex:'.$count])){return null;}

    echo '<div class="alignments">';
    echo '<table><tr><th>source</th><th>target</th>';
//    echo '<th>score</th>';
    echo '</tr>';
    while (isset($_SESSION['alignLex:'.$count])){
	list($src,$trg) = explode(':',$_SESSION['alignLex:'.$count]);
	echo "<tr id=\"l$count\">";
	echo '<td>'.htmlentities($src).'</td>';
	echo '<td>'.htmlentities($trg).'</td>';
//	echo '<td>'.$_SESSION['alignScore:'.$count].'</td>';
	echo '</tr>';
	$count++;
    }
    echo '</table>';
    echo '</div>';
}



/////////////////////////////////////////////////////////////
// print the clue matrix!


function print_bitext_segment(){

    $nr_src = $_SESSION['nrSrc'];
    $nr_trg = $_SESSION['nrTrg'];

    if (! $nr_src>0){return 0;}
    if (! $nr_trg>0){return 0;}

    echo '<div class="bitext">';
    echo '<b>[1]</b> ';
    for ($i=0;$i<=$_SESSION['nrSrc'];$i++){
	echo '<span id="ws'.$i.'" ';
	if (isset($_SESSION['marked_src']) && $_SESSION['marked_src'] == $i){
	    echo "style='background-color:#ccccff'";
	    echo " onClick=\"window.location = '$PHP_SELF?us=$i'\"";
	}
	else{
	    echo "onMouseOver=\"setStyle(this,'backgroundColor','#ccccff')\" ";
	    echo "onMouseOut=\"setStyle(this,'backgroundColor','#ffffff')\"";
	    echo " onClick=\"window.location = '$PHP_SELF?ms=$i'\"";
	}
	echo '>';
	echo htmlentities($_SESSION['srcToken:'.$i]).'</span> ';
    }
    echo '<br>';
    echo '<b>[2]</b> ';
    for ($i=0;$i<=$_SESSION['nrTrg'];$i++){
	echo '<span id="wt'.$i.'"';
	if (isset($_SESSION['marked_trg']) && $_SESSION['marked_trg'] == $i){
	    echo "style='background-color:#ccccff'";
	    echo " onClick=\"window.location = '$PHP_SELF?ut=$i'\"";
	}
	else{
	    echo "onMouseOver=\"setStyle(this,'backgroundColor','#ccccff')\" ";
	    echo "onMouseOut=\"setStyle(this,'backgroundColor','#ffffff')\"";
	    echo " onClick=\"window.location = '$PHP_SELF?mt=$i'\"";
	}
	echo '>';
	echo htmlentities($_SESSION['trgToken:'.$i]).'</span> ';
    }
    echo '</div>';
}


/////////////////////////////////////////////////////////////
// print the clue matrix!


function print_clue_matrix(){

    $nr_src = $_SESSION['nrSrc'];
    $nr_trg = $_SESSION['nrTrg'];

    if (! $nr_src>0){return 0;}
    if (! $nr_trg>0){return 0;}

    $srcwords = array();
    $trgwords = array();

    // compute level of magnitude

    $highest = $_SESSION['highestScore'];
    $lowest = $_SESSION['lowestScore'];

    $val = $highest;
    $magn = 1;
    if ($highest>0){
	while ((10*$val)<100){
	    $magn *= 10;
	    $val *= 10;
	}
    }


    // print the matrix

    echo '<div class="cluematrix">';
    echo '<table><tr><th></th>';

    for ($j=0;$j<=$nr_trg;$j++){
	echo "<th id=\"t$j\">".htmlentities($_SESSION['trgToken:'.$j]).'</th>';
    }
    echo '</tr>';

    for ($i=0;$i<=$nr_src;$i++){
	echo "<tr><th id=\"s$i\">";
	echo htmlentities($_SESSION['srcToken:'.$i]).'</th>';
	for ($j=0;$j<=$nr_trg;$j++){

	    $val = null;
	    unset($color);
	    unset($hex);

	    if (isset($_SESSION['matrix:'.$i.':'.$j])){
		$val=$_SESSION['matrix:'.$i.':'.$j];
	    }

	    if (($val!=null) && (($highest-$lowest)>0)){
		$color = 255-($val-$lowest)*255/($highest-$lowest);
//		$color = 128-($val-$lowest)*128/($highest-$lowest);
//		$color = 256-($val-$lowest)*128/($highest-$lowest);
		$hex=sprintf("%X",round($color));
		if (strlen($hex)<2){$hex="0$hex";}
	    }

	    //////////////////////////////////////////
	    // aligned items belong to class 'aligned'
	    // make blue borders when mouseOver

	    if (isset($_SESSION['link:'.$i.':'.$j])){

		$in_link = $_SESSION['inLink:'.$i.':'.$j];
		echo "\n<td class=\"aligned\" 
                onMouseOver=\"markAligned(this,'s$i','t$j','l$in_link')\" 
                onMouseOut=\"unmarkAligned(this,'s$i','t$j','#ff0000','l$in_link')\" 
                onClick=\"window.location = '$PHP_SELF?rm=$i:$j'\"";
		if (isset($hex)){
		    echo " bgcolor=\"#ff$hex$hex\"";
		}
		echo ">";
	    }
	    else{
		echo "\n<td class=\"notaligned\" 
                onMouseOver=\"markUnaligned(this,'s$i','t$j')\" 
                onMouseOut=\"unmarkUnaligned(this,'s$i','t$j','#ffffff')\" 
                onClick=\"window.location = '$PHP_SELF?add=$i:$j'\"";
		if (isset($hex)){
		    echo " bgcolor=\"#$hex$hex$hex\"";
		}
		echo ">";
	    }

            //////////////////////////////////////////////
	    // tooltip popup for showing mathcing clues

	    if (isset($_SESSION['clues:'.$i.':'.$j])){
//		echo "\n<span onMouseOver=\"this.T_FONTSIZE='14px';return escape('";
		echo "\n<span onMouseOver=\"return escape('";
		if (isset($_SESSION['link:'.$i.':'.$j])){
		    $inlink = $_SESSION['inLink:'.$i.':'.$j];
		    echo htmlentities(str_replace('"','&quot;',
			 str_replace("'","\\'",
                         'in alignment: '.$_SESSION['alignLex:'.$inlink])));
		    echo '<hr>';
		}

		echo $_SESSION['clues:'.$i.':'.$j];
		echo "')\">";

		///////////////////////////////////////////
		// black or white text color 
		// (depending on the background color)
		if (isset($color) && ($color<128)){
		    echo '<font color="#ffffff">';
		    echo round($val*$magn,2);
		    echo '</font>';
		}
		else{
		    echo round($val*$magn,2);
		}
	    }
	    else{
//		echo '-';
		echo round($val*$magn,2);
	    }

            //////////////////////////////////////////////

	    echo '</td>';
	}
	echo '</tr>';
    }
    echo '</table>';
    echo "<p>All values X ".$magn.'! ';
    echo '</div>';
}









///////////////////////////////////////////////////////////////////
// show the contents of a clue DBM file


function ShowDBM($dbm){
    global $UPLUGHOME;
    global $CLUES;

    // navigation links (start, previous, next)

    echo '<table><tr>';
    echo "<td><form action=\"$PHP_SELF\" method=\"post\">";
    echo '<input type="hidden" name="showdbm" value="';
    echo $_REQUEST['showdbm'].'">';
    if (isset($_REQUEST['sort'])){
	echo '<input type="hidden" name="sort" value="';
	echo $_REQUEST['sort'].'">';
    }
    echo '<a href="#" style="text-decoration:none" onclick="parentNode.submit()">&lt;&lt;</a>';
    echo '</form></td>';

    if (isset($_REQUEST['skip'])){
	if (($_REQUEST['skip'] - 25) > 0){
	    $prev = $_REQUEST['skip'] - 25;
	    echo "<td><form action=\"$PHP_SELF\" method=\"post\">";
	    echo '<input type="hidden" name="showdbm" value="';
	    echo $_REQUEST['showdbm'].'">';
	    echo '<input type="hidden" name="skip" value="'.$prev.'">';
	    if (isset($_REQUEST['sort'])){
		echo '<input type="hidden" name="sort" value="';
		echo $_REQUEST['sort'].'">';
	    }
	    echo '<a href="#" style="text-decoration:none" onclick="parentNode.submit()">&lt;</a>';
	    echo '</form></td>';
	}
    }

    echo '<td valign="top"> [ '.$_REQUEST['showdbm'].' ] </td>';

    $next = $_REQUEST['skip'] + 25;
    echo "<td><form action=\"$PHP_SELF\" method=\"post\">";
    echo '<input type="hidden" name="showdbm" value="';
    echo $_REQUEST['showdbm'].'">';
    echo '<input type="hidden" name="skip" value="'.$next.'">';
    if (isset($_REQUEST['sort'])){
	echo '<input type="hidden" name="sort" value="';
	echo $_REQUEST['sort'].'">';
    }
    echo '<a href="#" style="text-decoration:none" onclick="parentNode.submit()">&gt;</a>';
    echo '</form></td></tr></table>';

    // end of navigation links

    echo '<div class="dbm">';
    echo '<table><tr>';

    // table header:
    // sort source links

    echo "<th><form action=\"$PHP_SELF\" method=\"post\">";
    echo '<input type="hidden" name="showdbm" value="';
    echo $_REQUEST['showdbm'].'">';
    if (isset($_REQUEST['skip'])){
	echo '<input type="hidden" name="skip" value="';
	echo $_REQUEST['skip'].'">';
    }
    if ($_REQUEST['sort'] == 'src'){
	echo '<input type="hidden" name="sort" value="rsrc">';
    }
    else{
	echo '<input type="hidden" name="sort" value="src">';
    }
    echo '<a href="#" style="text-decoration:none" onclick="parentNode.submit()">source</a>';
    echo '</form></th>';

    // sort target links

    echo "<th><form action=\"$PHP_SELF\" method=\"post\">";
    echo '<input type="hidden" name="showdbm" value="';
    echo $_REQUEST['showdbm'].'">';
    if (isset($_REQUEST['skip'])){
	echo '<input type="hidden" name="skip" value="';
	echo $_REQUEST['skip'].'">';
    }
    if ($_REQUEST['sort'] == 'trg'){
	echo '<input type="hidden" name="sort" value="rtrg">';
    }
    else{
	echo '<input type="hidden" name="sort" value="trg">';
    }
    echo '<a href="#" style="text-decoration:none" onclick="parentNode.submit()">target</a>';
    echo '</form></th>';


    // sort scores links

    echo "<th><form action=\"$PHP_SELF\" method=\"post\">";
    echo '<input type="hidden" name="showdbm" value="';
    echo $_REQUEST['showdbm'].'">';
    if (isset($_REQUEST['skip'])){
	echo '<input type="hidden" name="skip" value="';
	echo $_REQUEST['skip'].'">';
    }
    if ($_REQUEST['sort'] == 'score'){
	echo '<input type="hidden" name="sort" value="rscore">';
    }
    else{
	echo '<input type="hidden" name="sort" value="score">';
    }
    echo '<a href="#" style="text-decoration:none" onclick="parentNode.submit()">score</a>';
    echo '</form></th></tr>';
    //echo '<th>source</th><th>target</th><th>score</th></tr>';

    // end f table header

    // search form

    echo "<form action=\"$PHP_SELF\" method=\"post\"><tr><td>";
    echo '<input type="text" name="source" size="12"></td>';
    echo '<td><input type="text" name="target" size="12"></td>';
    echo '<td><input type="submit" value="search">';
    echo '<input type="hidden" name="showdbm" value="';
    echo $_REQUEST['showdbm'].'">';
    echo '</td></tr></form>';



    $command = $UPLUGHOME.'/tools/dumpdbm '.$CLUES[$dbm];
    $command .= ' | tr "\00=>" "~~~" | cut -d "~" -f1,2,5';

    ///////////////////////////////////////////////////////////////////////
    // query the clue DBM ... (this is probably not safe!?!?)

    if (($_POST['source'] != "") || ($_POST['target'] != "")){

	// replace all single quotes with nothing
	// (is that safe enough?)
	$src_pattern = str_replace("'","",$_POST['source']);
	$trg_pattern = str_replace("'","",$_POST['target']);

	if ($trg_pattern == ""){
	    $command .= " | egrep '^ *".utf8_encode($src_pattern)." *~'";
	}
	elseif ($src_pattern == ""){
	    $command .= " | egrep '~ *".utf8_encode($trg_pattern)." *~'";
	}
	else{
	    $command = $UPLUGHOME.'/tools/searchdbm '.$CLUES[$dbm];
	    $command .= ' '.utf8_encode($src_pattern);
	    $command .= ' '.utf8_encode($trg_pattern);
	    $output = shell_exec('ulimit -t 2;'.$command);
	    list($key,$val) = explode(' => ',$output);
	    list($src,$trg) = explode("\x00",$key);
	    list($field,$score) = explode("\x00",$val);
	    echo '<tr><td>'.htmlentities(utf8_decode($src)).'</td>';
	    echo '<td>'.htmlentities(utf8_decode($trg)).'</td>';
	    echo '<td>'.$score.'</td></tr>';
	    echo '</table></div>';
	    return $output;
	}
    }

    elseif (isset($_REQUEST['sort'])){
	if ($_REQUEST['sort'] == 'trg'){
	    $command .= ' | sort +1 -t "~"';
	}
	elseif ($_REQUEST['sort'] == 'rtrg'){
	    $command .= ' | sort +2 -r -t "~"';
	}
	elseif ($_REQUEST['sort'] == 'score'){
	    $command .= ' | sort +2 -n -t "~"';
	}
	elseif ($_REQUEST['sort'] == 'rscore'){
	    $command .= ' | sort +2 -n -r -t "~"';
	}
	elseif ($_REQUEST['sort'] == 'rsrc'){
	    $command .= ' | sort +2 -r -t "~"';
	}
	else{
	    $command .= ' | sort -t "~"';
	}
    }
    $command .= ' | tr "~~~" "\t\t\t"';
    if (isset($_REQUEST['skip'])){
	$command .= ' | tail +'.$_REQUEST['skip'];
    }
    $command .= ' | head -25';

    // echo $command.'<br>';

    $output = shell_exec('ulimit -t 2;'.$command);
    $lines = explode("\n",$output);


    foreach ($lines as $line){
	list($src,$trg,$score) = explode("\t",$line);
	$src = htmlentities(utf8_decode($src));
	$trg = htmlentities(utf8_decode($trg));

	echo '<tr><td>'.$src.'</td><td>'.$trg.'</td><td>'.$score.'</td></tr>';
    }
    echo '</table></div>';
}

/// end of ShowDBM
/////////////////////////////////////////////////////////////////////////




?>