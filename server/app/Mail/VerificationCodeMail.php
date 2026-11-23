<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

class VerificationCodeMail extends Mailable
{
    public function __construct(
        public string $code,
        public string $name,
        public int $minutes,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: "Your eBarangay Mo verification code: {$this->code}");
    }

    public function content(): Content
    {
        return new Content(
            view: 'mail.verification-code',
            text: 'mail.verification-code-text',
        );
    }
}
