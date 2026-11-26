<?php

namespace App\Services;

use finfo;
use Imagick;
use Throwable;

/**
 * Photo uploads from any phone.
 *
 * detect(): decides what a file really is from its bytes (magic numbers),
 * never from the filename or the Content-Type the client claims. Only real
 * image formats pass, so "shell.php" renamed to ".jpg" is still rejected.
 *
 * normalize(): re-encodes every accepted photo as a plain JPEG (when the
 * Imagick extension is installed, as in the production image). This
 *  - turns iPhone/Android HEIC, AVIF, GIF, BMP... into something every
 *    browser can show to the admin,
 *  - removes EXIF metadata such as the GPS location where the photo was taken,
 *  - drops anything hidden after or inside the image data,
 *  - shrinks very large photos to at most MAX_SIDE pixels.
 * Without Imagick the original bytes are kept (they already passed detect()).
 */
class ImageUpload
{
    public const MAX_KB = 15360; // 15 MB per photo

    public const MAX_SIDE = 2000; // pixels, longest side after normalizing

    /** Real MIME type => ImageMagick decoder. Nothing outside this list is ever decoded. */
    private const FORMATS = [
        'image/jpeg' => 'JPEG',
        'image/png' => 'PNG',
        'image/webp' => 'WEBP',
        'image/gif' => 'GIF',
        'image/bmp' => 'BMP',
        'image/x-ms-bmp' => 'BMP',
        'image/heic' => 'HEIC',
        'image/heif' => 'HEIC',
        'image/heic-sequence' => 'HEIC',
        'image/heif-sequence' => 'HEIC',
        'image/avif' => 'AVIF',
    ];

    /** HEIF container brands used by phones (iPhone: heic/mif1, Samsung: heic/heix...). */
    private const HEIC_BRANDS = ['heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'hevm', 'hevs', 'mif1', 'msf1'];

    private const AVIF_BRANDS = ['avif', 'avis'];

    /** The real image type of these bytes, or null if they are not an accepted image. */
    public static function detect(string $bytes): ?string
    {
        // HEIC/AVIF are checked by hand: older libmagic versions don't know them.
        $brands = self::isoBrands($bytes);
        if (array_intersect($brands, self::AVIF_BRANDS)) {
            return 'image/avif';
        }
        if (array_intersect($brands, self::HEIC_BRANDS)) {
            return 'image/heic';
        }
        if ($brands) {
            return null; // other ISO media, e.g. an MP4/MOV video
        }

        $mime = (new finfo(FILEINFO_MIME_TYPE))->buffer($bytes);

        return isset(self::FORMATS[$mime]) ? $mime : null;
    }

    /** @return array{bytes: string, mime: string} */
    public function normalize(string $bytes): array
    {
        $mime = self::detect($bytes);
        if ($mime === null || ! extension_loaded('imagick')) {
            return ['bytes' => $bytes, 'mime' => (string) $mime];
        }

        try {
            return ['bytes' => $this->toJpeg($bytes, self::FORMATS[$mime]), 'mime' => 'image/jpeg'];
        } catch (Throwable $e) {
            // E.g. no HEIC support in this ImageMagick build. The photo is still
            // a verified image, so keep it rather than lose the submission.
            report($e);

            return ['bytes' => $bytes, 'mime' => $mime];
        }
    }

    private function toJpeg(string $bytes, string $format): string
    {
        // Caps against "decompression bombs" (a small file that expands to
        // billions of pixels). Past these, ImageMagick refuses the image.
        Imagick::setResourceLimit(Imagick::RESOURCETYPE_AREA, 120_000_000);   // ~120 megapixels
        Imagick::setResourceLimit(Imagick::RESOURCETYPE_MEMORY, 256 * 1024 * 1024);
        Imagick::setResourceLimit(Imagick::RESOURCETYPE_MAP, 512 * 1024 * 1024);
        Imagick::setResourceLimit(Imagick::RESOURCETYPE_DISK, 1024 * 1024 * 1024);
        if (defined('Imagick::RESOURCETYPE_TIME')) {
            Imagick::setResourceLimit(Imagick::RESOURCETYPE_TIME, 30);
        }

        $source = new Imagick;
        // The decoder is fixed from the verified type, so ImageMagick never
        // guesses (no SVG/MVG/script coders can be reached).
        $source->setFormat($format);
        $source->readImageBlob($bytes);

        // Animated GIF / HEIC burst: keep the first frame.
        $source->setIteratorIndex(0);
        $image = $source->getImage();
        $source->clear();

        $this->applyOrientation($image);

        // Transparent areas (PNG, GIF) become white instead of black.
        $image->setImageBackgroundColor('white');
        $image->setImageAlphaChannel(Imagick::ALPHACHANNEL_REMOVE);
        $image->transformImageColorspace(Imagick::COLORSPACE_SRGB);

        if ($image->getImageWidth() > self::MAX_SIDE || $image->getImageHeight() > self::MAX_SIDE) {
            $image->thumbnailImage(self::MAX_SIDE, self::MAX_SIDE, true);
        }

        $image->stripImage(); // EXIF (GPS), comments, embedded profiles
        $image->setImageFormat('JPEG');
        $image->setImageCompressionQuality(85);
        $jpeg = $image->getImageBlob();
        $image->clear();

        return $jpeg;
    }

    /** Phones store "rotate me" in EXIF; bake it in, since stripImage() removes the tag. */
    private function applyOrientation(Imagick $image): void
    {
        match ($image->getImageOrientation()) {
            Imagick::ORIENTATION_TOPRIGHT => $image->flopImage(),
            Imagick::ORIENTATION_BOTTOMRIGHT => $image->rotateImage('#000', 180),
            Imagick::ORIENTATION_BOTTOMLEFT => $image->flipImage(),
            Imagick::ORIENTATION_LEFTTOP => $image->transposeImage(),
            Imagick::ORIENTATION_RIGHTTOP => $image->rotateImage('#000', 90),
            Imagick::ORIENTATION_RIGHTBOTTOM => $image->transverseImage(),
            Imagick::ORIENTATION_LEFTBOTTOM => $image->rotateImage('#000', -90),
            default => null,
        };
        $image->setImageOrientation(Imagick::ORIENTATION_TOPLEFT);
    }

    /** Brands of an ISO-BMFF file (HEIC, AVIF, MP4...), or [] if it isn't one. */
    private static function isoBrands(string $bytes): array
    {
        if (strlen($bytes) < 16 || substr($bytes, 4, 4) !== 'ftyp') {
            return [];
        }

        $boxSize = min(unpack('N', substr($bytes, 0, 4))[1], 256, strlen($bytes));
        $brands = [substr($bytes, 8, 4)]; // major brand
        for ($i = 16; $i + 4 <= $boxSize; $i += 4) {
            $brands[] = substr($bytes, $i, 4); // compatible brands
        }

        return $brands;
    }
}
