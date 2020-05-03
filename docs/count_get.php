// Assumes at least 1 item will be changed when update is posted
$arr = array($pid);
$count = 2;
$query = "UPDATE pokecaught SET ";
if (isset($_GET['lvl'])) {
	$query .= 'lvl = $' . $count++ . ', ';
	array_push($arr, $_GET['lvl']);
}
if (isset($_GET['nick'])) {
	$query .= 'nick = $'. $count++ . ', ';
	array_push($arr, trim($_GET['nick']));
}
if (isset($_GET['happiness'])) {
	$query .= 'happiness = $'. $count++ . ', ';
	array_push($arr, $_GET['happiness']);
if (isset($_GET['evolved'])) {
	$query .= 'pindex = $'. $count++ . ', ';
	array_push($arr, $_GET['pindex']);
}
if (isset($_GET['banked'])) {
	$query .= 'banked = $'. $count++ . ', ';
	array_push($arr, $_GET['banked']);
}
if (isset($_GET['evs'])) {
	$evs = explode(",", $_GET["evs"]);
	$query .= 'hpev = $' . $count++ . ', ' . 'atkev = $' . $count++ . ', ' .
			  'defev = $' . $count++ . ', ' . 'speev = $' . $count++ . ', ' .
			  'spaev = $' . $count++ . ', ' . 'spdev = $' . $count++ . ', ';
	$arr = array_merge($arr, $evs);
}

pg_prepare($dbconn, "updatepoke", substr($query, 0, -2) . ' WHERE pid = $1');
pg_execute($dbconn, "updatepoke", $arr);

if (isset($_GET['rename'])) logRename($pid);
if (isset($_GET['evolved'])) logEvolved($pid);