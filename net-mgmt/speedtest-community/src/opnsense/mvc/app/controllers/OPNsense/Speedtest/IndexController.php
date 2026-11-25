<?php

/*
 * Copyright 2021 Miha Kralj
 *    All rights reserved.
 *
 *    Redistribution and use in source and binary forms, with or without
 *    modification, are permitted provided that the following conditions are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 *    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 *    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 *    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 *    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *    POSSIBILITY OF SUCH DAMAGE.
 *
 */
namespace OPNsense\Speedtest;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $acl = new \OPNsense\Core\ACL();
        $readOnly = $acl->hasPrivilege($this->getUserName(), 'user-config-readonly');
        $this->view->canRun = !$readOnly && $acl->isPageAccessible($this->getUserName(), '/api/speedtest/service/run/0/both');
        $this->view->canConfigure = !$readOnly && $acl->isPageAccessible($this->getUserName(), '/api/speedtest/settings/set');
        $this->view->canClear = !$readOnly && $acl->isPageAccessible($this->getUserName(), '/api/speedtest/service/deletelog');
        $this->view->canSchedule = !$readOnly && $acl->isPageAccessible($this->getUserName(), '/api/speedtest/schedule/set');
        $this->view->pick('OPNsense/Speedtest/index');
    }
}
