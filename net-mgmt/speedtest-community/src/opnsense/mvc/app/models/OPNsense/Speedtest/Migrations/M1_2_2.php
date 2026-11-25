<?php

namespace OPNsense\Speedtest\Migrations;

use OPNsense\Base\BaseModelMigration;

class M1_2_2 extends BaseModelMigration
{
    public function run($model)
    {
        parent::run($model);
        if ((string)$model->general->timeout === '8') {
            $model->general->timeout = '15';
        }
    }
}
