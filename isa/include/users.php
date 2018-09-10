<?php


function logged_in ( ) {

    // already logged in! --> return true

    if (isset($_SESSION['user'])){
	return true;
    }

    global $ALLOW_NEW_USERS;

    $passfile = 'corpora/'.$_SESSION['corpus'].'/users.php';
    if (file_exists($passfile)){
	include($passfile);
	if (isset($_POST['user']) && isset($_POST['password'])){
	    if (isset($USER[$_POST['user']])){
		if ($USER[$_POST['user']] === $_POST['password']){
		    $_SESSION['user'] = $_POST['user'];
		    return true;
		}
		if ($ALLOW_NEW_USERS){
		    echo "<br /><br /><br />";
		    echo "User ".$_POST['user']." exists already!";
		    echo "<br />Try a different user name!<br/><br />";
//		    login_form();
		    return false;
		}
		else{
		    echo "<br /><br /><br />";
		    echo "Login failed!<br />";
		    echo "Try again!<br /><br />";
		}
	    }
	    elseif ($ALLOW_NEW_USERS){
		if (add_user($passfile,$_POST['user'],$_POST['password'])){
		    $_SESSION['user'] = $_POST['user'];
		    return true;
		}
		echo "<br /><br /><br />";
		echo "Login failed!<br />";
		echo "Try again!<br /><br />";
	    }
	    else{
		echo "<br /><br /><br />";
		echo "Login failed!<br />";
		echo "Try again!<br /><br />";
	    }
	}
    }
    elseif (add_user($passfile,$_POST['user'],$_POST['password'])){
	$_SESSION['user'] = $_POST['user'];
	return true;
    }
    else{
	echo "<br /><br /><br />";
	echo "Login failed!<br />";
	echo "Try again!<br /><br />";
    }

    echo "<br /><br /><br /><h2>Login</h2>";

    if (!file_exists($passfile)){
	echo "Create a user using the form below!<br/>";
	echo "Please use the following characters only: a-zA-Z0-9_<br /><br/>";
    }
    elseif ($ALLOW_NEW_USERS){
	echo "Login or create a new user using the form below!<br/>";
	echo "Please use the following characters only: a-zA-Z0-9_<br /><br/>";
    }

    echo "<form action=\"$PHP_SELF\" method=\"post\">";
    echo 'username: <input type="user" name="user"><br />';
    echo 'password: <input type="password" name="password"><br />';
    echo '<p><input type="submit" name="submit" value="login"></p>';
    echo '</form>';

    return false;

}



function add_user($passfile,$user,$password){

    if (file_exists($passfile)){
	include($passfile);
    }

    if (!preg_match('/^[a-zA-Z0-9_]+$/',$user)){
	return false;
    }
    if (!preg_match('/^[a-zA-Z0-9_]+$/',$password)){
	return false;
    }
//    $user = strtr($user,"'",'_');
//    $password = strtr($password,"'",'_');

    for ($i=1;$i<5;$i++){
	$fh = fopen($passfile,'w');
	if ($fh){
	    flock( $fh, LOCK_EX );
	    break;
	}
	sleep(1);
    }
    if ($fh){
	fwrite($fh,"<?php \n\$USER = array(\n");
	if (is_array($USER)){
	    foreach ($USER as $name => $passw){
		fwrite($fh,"'".$name."' => '".$passw."',\n");
	    }
	}
	fwrite($fh,"'".$user."' => '".$password."'\n);\n");
    }
    fwrite($fh,"?>\n");
    $lock = flock( $fh, LOCK_UN );
    fclose( $fh );

    $corpusdir = 'corpora/'.$_SESSION['corpus'];
    $userdir = 'corpora/'.$_SESSION['corpus'].'/'.$user;
    $path = realpath($corpusdir);

    if (file_exists($corpusdir) && !file_exists($userdir)){
	if (@mkdir($userdir)){
	    @copy($corpusdir.'/config.inc',$userdir.'/config.inc');
	    @copy($corpusdir.'/link',$userdir.'/link');
	    @symlink($path.'/data',$userdir.'/data');
	}
    }

    return true;
}



?>