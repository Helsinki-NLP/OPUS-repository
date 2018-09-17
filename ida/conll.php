<?php


function read_sentence($fp,&$lines){
  while ($line = fgets($fp)){
    $line = trim($line);
    if (!strlen($line)){
      return count($lines);
    }
    array_push($lines,$line);
  }
  return false;
}



function save_deprels($dbfile,$id,&$heads,&$deprels){
  $db = dba_open( $dbfile, "w", "db4") or die('ssss');
  if (dba_exists($id,$db)){
    $string = trim(dba_fetch($id,$db));
  }

  $oldlines = explode("\n",$string);
  $newlines = array();
  $i = 1;
  foreach ($oldlines as $line){
    $parts = explode("\t",$line);
    //echo $parts[6]."..$i...".$heads[$i]."====<br/>";
    //echo $parts[7]."..$i...".$deprels[$i]."====<br/>";
    $parts[6] = $heads[$i];
    $parts[7] = $deprels[$i];
    array_push($newlines,implode("\t",$parts));
    $i++;
  }
  $string = implode("\n",$newlines);
  dba_replace($id,$string,$db);
  dba_close($db);
}


function read_deprels($dbfile,$id,&$words,&$heads,&$deprels){

  $db = dba_open( $dbfile, "r", "db4") or die('ssss');
  if (dba_exists($id,$db)){
    $string = trim(dba_fetch($id,$db));
  }
  dba_close($db);

  $lines = explode("\n",$string);
  $words = array('-root-');
  $heads = array(NULL);
  $deprels = array(NULL);

  foreach ($lines as $line){
    $parts = explode("\t",$line);
    $id = count($words);
    // $head = $parts[6]-1;
    $head = $parts[6];
    if ( $parts[6] == 0 ) {$head = "0";}
    array_push($words,$parts[1]);
    array_push($heads,$head);
    array_push($deprels,$parts[7]);
  }
}





?>