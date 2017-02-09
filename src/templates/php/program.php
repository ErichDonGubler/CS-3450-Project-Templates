<?php
require_once("src/pattern_module.php");

function main($argc, $argv) {
    $p = new Pattern();
    $p->doSomething();
}

main($_SERVER['argc'], $_SERVER['argv']);
