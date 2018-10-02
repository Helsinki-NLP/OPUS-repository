<?php

function print_links($links,$SPositions,$TPositions,$SY=210,$TY=260,$arg='rl'){

  $svg = '';
  foreach ($links as $link => $conf){
    list($src,$trg) = explode('-',$link);
    if (array_key_exists($src,$SPositions)){
      if (array_key_exists($trg,$TPositions)){
	$x1 = $SPositions[$src];
	$x2 = $TPositions[$trg];
	$svg .="<a xlink:href='?$arg=$src-$trg'>";  
	$svg .= "<line x1='$x1' y1='$SY' x2='$x2' y2='$TY' style='stroke:black;stroke-width:1' />";
	$svg .='</a>';
      }
    }
  }
  return $svg;
  }

function save_links($dbfile,$id,&$links){
  $mode = "c";
  if (file_exists($dbfile)){ $mode = "w"; }
  $db = dba_open( $dbfile, $mode, "db4") or die('ssss');
  $string = implode(" ",array_keys($links));
  dba_replace($id,$string,$db);
  dba_close($db);
}

function read_links($dbfile,$id,&$links){
  if (file_exists($dbfile)){
    $db = dba_open( $dbfile, "r", "db4") or die('ssss');
    if (dba_exists($id,$db)){
      $string = trim(dba_fetch($id,$db));
      $alg = explode(" ",$string);
      $links = array_fill_keys($alg, 1);
    }
    dba_close($db);
  }
}


?>