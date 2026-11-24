<?php
declare(strict_types=1);

// El portal vive en /cliente/. La raiz solo redirige para tener una URL canonica.
header('Location: /cliente/', true, 302);
exit;
