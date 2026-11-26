<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * Railway terminates TLS and forwards requests over plain HTTP with
 * X-Forwarded-Proto: https. The HTTPS redirect must trust that header,
 * or every request redirects forever (ERR_TOO_MANY_REDIRECTS).
 */
class ForceHttpsTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['security.force_https' => true]);
    }

    public function test_request_that_was_https_at_the_proxy_is_not_redirected(): void
    {
        $this->get('http://e-barangay.test/up', ['X-Forwarded-Proto' => 'https'])
            ->assertOk();
    }

    public function test_plain_http_is_redirected_to_https(): void
    {
        $this->get('http://e-barangay.test/up')
            ->assertStatus(301)
            ->assertRedirect('https://e-barangay.test/up');
    }
}
