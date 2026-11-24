<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';
authStart();
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();
}
$_SESSION = [];
session_regenerate_id(true);
redirectTo('/cliente/login.php');
