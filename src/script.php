<?php
	$im = imagecreatefrompng("D:\Dev\mp_nuzlocke\sprites\p1.png");
	header('Content-Type: image/png');
	imagepng($im);
	imagedestroy($im);
?>