<?php

//////////////////////////////////////////////////////////
// you should change the following settings
//////////////////////////////////////////////////////////

$SRCXML = 'corpora/1988en.xml';       // source language document (in XML)
$TRGXML = 'corpora/1988fr.xml';       // target language document (in XML)
$BITEXT = 'corpora/1988enfr.ces';       // sentence alignments of your bitext (full path)
$LANGPAIR = 'enfr';   // language IDs for your language pair
$INVLANG = 'fren'; // (and target -> source language)

$UPLUGHOME = 'uplug';    // path to Uplug (accessible from PHP!)
$DATADIR = dirname($BITEXT); // directory for saving data (has to be writable!)
//$DATADIR = '%%DATADIR%%';  // directory for saving data (has to be writable!)

///////////////////////////////////////////////////////////////////
// ... but you probably don't have to touch the settings below ...
///////////////////////////////////////////////////////////////////


$UPLUG = $UPLUGHOME.'/uplug';
$ALIGN = $UPLUGHOME.'/ext/align/align2';         // sentence aligner (for ISA)
$SENTTAG = 's';                                  // sentence tag in XML files
$SENTLINKTAG = 'link';                           // XML tag for sentence links
$HARDTAGS = array('p' => 'paragraphs',           // possible XML tags to be
		  'pb' => 'page breaks');        // used as hard boundaries
$SHOWMAX = 20;                                   // max nr of sentences in ISA
$CLUEDIR = 'data/runtime';
$LANGCLUEDIR = $UPLUGHOME.'/lang/'.$LANGPAIR;

$CLUES = array(
    'dice' => $CLUEDIR.'/dice.dbm',                  // basic clues
    'mi' => $CLUEDIR.'/mi.dbm',
    'tscore' => $CLUEDIR.'/tscore.dbm',
    'sim' => $CLUEDIR.'/str.dbm',
    'gw' => $CLUEDIR.'/giza-word.dbm',               // giza clues
    'gwi' => $CLUEDIR.'/giza-word-i.dbm',
    'gp' => $CLUEDIR.'/giza-pos.dbm',
    'gpi' => $CLUEDIR.'/giza-pos-i.dbm',
    'gwp' => $CLUEDIR.'/giza-word-prefix.dbm',
    'gwpi' => $CLUEDIR.'/giza-word-prefix-i.dbm',
    'gws' => $CLUEDIR.'/giza-word-suffix.dbm',
    'gwsi' => $CLUEDIR.'/giza-word-suffix-i.dbm',
    'dl3x' => $CLUEDIR.'/dl3x.dbm',                  // dynamic clues
    'dl' => $CLUEDIR.'/dl.dbm',
    'dlp' => $CLUEDIR.'/dlp.dbm',
    'dlx' => $CLUEDIR.'/dlx.dbm',
    'dpx' => $CLUEDIR.'/dpx.dbm',
    'dp3x' => $CLUEDIR.'/dp3x.dbm',
    'dc3' => $CLUEDIR.'/dc3.dbm',
    'dc3p' => $CLUEDIR.'/dc3p.dbm',
    'dc3x' => $CLUEDIR.'/dc3x.dbm',
    $LANGPAIR.'p' => $LANGCLUEDIR.'/pos.dbm',         // static clues
    $LANGPAIR.'pp' => $LANGCLUEDIR.'/pos2.dbm',
    $LANGPAIR.'c' => $LANGCLUEDIR.'/chunk.dbm',


    'ep-'.$LANGPAIR.'-gw' => $LANGCLUEDIR.'/ep-giza-word-'.$LANGPAIR.'.dbm',
    'ep-'.$LANGPAIR.'-gwi' => $LANGCLUEDIR.'/ep-giza-word-'.$INVLANG.'.dbm'
);


?>
