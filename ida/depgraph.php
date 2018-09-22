<?php

function print_graph($words,$heads,$deprels,
		     $MarkedWord=NULL,$MarkedLabel=NULL,
		     $PosX=50,$PosY=200,$flip=1,
		     $WordArg='w',$EdgeArg='e',$LabelArg='l'){

  global $boxX,$boxY1,$boxY2,$anchorPos;
  
  $svg = '';
  $pos=$PosX;
  $wordpos = array();
  $wordlen = array();

  // count outging links per node
  // separated by left and right-branching links
  $outlinks = array();
  $leftdist = array();
  $rightdist = array();
  for ($i=0;$i<count($words);$i++){
    $outlinks[$heads[$i]]++;
    $dist = $i-$heads[$i];
    if ($heads[$i]>$i){
      $leftdist[$heads[$i]][$dist]++;
    }
    else{
      $rightdist[$heads[$i]][$dist]++;
    }
  }

  // compute an offset for each head node
  // longest distance --> clostest to the middle
  $StartOffset = array();
  for ($i=0;$i<count($words);$i++){
    ksort($leftdist[$i],SORT_NUMERIC);
    krsort($rightdist[$i],SORT_NUMERIC);
    $count = -1;
    foreach ($leftdist[$i] as $dist => $nr){
      $StartOffset[$i][$dist] = $count;
      $count--;
    }
    $count = +1;
    foreach ($rightdist[$i] as $dist => $nr){
      $StartOffset[$i][$dist] = $count;
      $count++;
    }
  }

  // anchor position stores the horizontal anchor positions for each word
  $anchorPos = array();

  for ($i=0;$i<count($words);$i++){

    $word=$words[$i];
    // a little hack to allow larger space for upper-case letters
    $len=strlen($word)*6;
    preg_match_all('/[A-Z]/',$word,$matches);
    $len+=1.3*count($matches[0]);

    $pos+=$len;

    $color='black';
    $class='normal';
    if (isset($MarkedWord)){
      if ($MarkedWord == $i){
	$color='red';
	$class='marked';
      }
      elseif (isset($heads[$MarkedWord]) && $heads[$MarkedWord]==$i){
	$color='blue';
	$class='linked';
      }
    }
    elseif (isset($MarkedLabel)){
      if ($MarkedLabel==$i){
	$color='blue';
	$class='linked';
      }
      elseif ($heads[$MarkedLabel]==$i){
	$color='blue';
	$class='linked';
      }
    }
    // echo "color --$i--$word-- ".$color.'<br/>';

    // font-family = 'sans-serif'
    // font-family = 'monospace'

    // $utf8 = utf8_decode($word);
    //    $utf8 = utf8_decode(mb_strtolower($word, 'UTF-8'));

    //    $svg.="<text x='$pos' y='$PosY' textLength='$len' lengthAdjust='spacingAndGlyphs' font-size='20' fill='$color' text-anchor='middle'><a xlink:href='?$WordArg=$i'>$word</a></text>";
    //$svg.="<text class='$class' x='$pos' y='$PosY' font-family='sans-serif' font-size='20' fill='$color' text-anchor='middle'><a class='$class' xlink:href='?$WordArg=$i'>$word</a></text>";
    $svg.="<text class='$class' x='$pos' y='$PosY' text-anchor='middle'><a class='$class' xlink:href='?$WordArg=$i'>$word</a></text>";


    //    $svg.="<text x='$pos' y='$PosY' font-size='20' fill='$color' text-anchor='middle'><a xlink:href='?$WordArg=$i'>$utf8</a></text>";

    array_push($wordpos,$pos);
    array_push($wordlen,$len);
    array_push($anchorPos,$pos);
    $pos+=$len+5;
  }

  for ($i=1;$i<count($words);$i++){
    if ($heads[$i] == NULL){ continue;}

    // set start, end and middle position of the arc
    $start = $wordpos[$heads[$i]];
    $end = $wordpos[$i];
    $middle = $start+($end-$start)/2;

    // move the start to the side
    $distance = $i-$heads[$i];
    $start += 4*$StartOffset[$heads[$i]][$distance];

      
    $height = $PosY-20*$flip-abs($start-$end)/4*$flip;
    if ($height-15 < $boxY1) { $boxY1 = $height-15; }
    if ($height > $boxY2) { 
      //$svg .= "<circle cx='$middle' cy='$height' r='20' stroke='black' stroke-width='2' fill='red'/>";
      //      $svg .= "<text x='10' y='$height' fill='black'>$height</text>";
      $boxY2 = $height; 
    }

    $StartPosY = $PosY-20*$flip;
    $EndPosY = $PosY-25*$flip;

    $color='black';
    if (isset($MarkedWord) && $MarkedWord == $i){
      $color='blue';
    }
    elseif (isset($MarkedLabel) && $MarkedLabel == $i){
      $color='blue';
    }

    $svg.="<a xlink:href='?$EdgeArg=$i'>";  
    $svg.="<path style='fill:none;stroke:$color;' d='M$start $StartPosY ";
    $svg.=" C$start $StartPosY $start $height $middle $height ";
    $svg.=" C$middle $height $end $height $end $EndPosY' ";
    $svg.='marker-end="url(#arrow)"/>';
    $svg.="</a>";

    $class='normal-label';
    $color='blue';
    if (isset($MarkedLabel) && $MarkedLabel == $i){
      $class='marked-label';
      $color='red';
    }
    if ($flip==-1){ $textY = $height+8; }
    else{ $textY = $height-4; }
    if ($start>$end){ $textX = $middle-10; }
    else{ $textX = $middle+10; }

    $svg.="\n<text x='$textX' y='";
    $svg.=$textY;
    // $svg.=$height;
    $svg.="' font-size='12' fill='$color' text-anchor='middle'>";
    $svg.="<a class='$class' xlink:href='?$LabelArg=$i'>";
    $svg.=$deprels[$i];
    $svg.="</a></text>\n";
  }
  if ($pos > $boxX) { $boxX = $pos; }
  return $svg;
}



function show_labels($i,$OldLabel,$file='ud-deprels.xx',
		     $EdgeArg='e',$LabelArg='nl'){
  global $IdaRootDir;
  $html = '';
  if (! file_exists($file)){
    $file=$IdaRootDir.'/ud-deprels.xx';
  }

  $deprels = file($file);
  //  $html.="<a href='?$EdgeArg=$i'>delete selected relation</a>";
  foreach ($deprels as $dep){
    $dep = trim($dep);
    if ($OldLabel == $dep){ $html.="$dep<br/>"; }
    else {
      $str=urlencode($dep);
      $html.="<a href='?$LabelArg=$str'>$dep</a><br/>";
    }
  }
  return $html;
}


function show_labels_svg($i,$OldLabel,$file='ud-deprels.xx',
		     $EdgeArg='e',$LabelArg='nl',
		     $PosX=10,$PosY=40){
  $svg = '';
  if (! file_exists($file)){
    $file='ud-deprels.xx';
  }

  $deprels = file($file);

   $svg.="<text x='$PosX' y='$PosY' font-size='16' fill='black'><a xlink:href='?$EdgeArg=$i'>delete selected relation</a></text>";
   $PosY+=20;
   $svg.="<text x='$PosX' y='$PosY' font-size='16' fill='black'>set new relation type:</text>";


  $PosY+=20;
  foreach ($deprels as $dep){
    $dep = trim($dep);
    if ($OldLabel == $dep){
      $svg.="<text x='$PosX' y='$PosY' font-size='12' fill='gray'>$dep</text>";
    }
    else {
      $str=urlencode($dep);
      $svg.="<text x='$PosX' y='$PosY' font-size='12' fill='black'><a xlink:href='?$LabelArg=$str'>$dep</a></text>";
    }
    $PosY+=10;
  }
  return $svg;
}


function set_status($dbfile,$id,$status){
  $db = dba_open( $dbfile, "c", "db4") or die('ssss');
  dba_replace($id,$status,$db);
  dba_close($db);
}

function get_status($dbfile,$id,$status){
  $db = dba_open( $dbfile, "r", "db4") or die('ssss');
  $status = '';
  if (dba_exists($id,$db)){
    $status = trim(dba_fetch($id,$db));
  }
  dba_close($db);
  return $status;
}



?>