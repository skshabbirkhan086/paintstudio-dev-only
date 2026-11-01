namespace PaintStudio.Api.Services;

public static class PngValidator
{
    public const int MaxBytes = 2 * 1024 * 1024;
    private const string Prefix = "data:image/png;base64,";
    private static readonly byte[] Signature = [137, 80, 78, 71, 13, 10, 26, 10];

    public static bool TryDecode(string? input, out byte[] png, out string? error)
    {
        png = [];
        error = null;
        if (string.IsNullOrWhiteSpace(input) || !input.StartsWith(Prefix, StringComparison.Ordinal))
        {
            error = "Expected a base64-encoded PNG data URL.";
            return false;
        }
        var encoded = input[Prefix.Length..];
        if (encoded.Length > (MaxBytes * 4 / 3) + 8)
        {
            error = "Painting exceeds the 2 MiB limit.";
            return false;
        }
        try { png = Convert.FromBase64String(encoded); }
        catch (FormatException)
        {
            error = "Invalid base64 image data.";
            return false;
        }
        if (png.Length is < 24 or > MaxBytes || !png.AsSpan(0, Signature.Length).SequenceEqual(Signature))
        {
            error = "Invalid PNG or painting exceeds the 2 MiB limit.";
            return false;
        }
        // Validate the PNG IHDR chunk and bounded dimensions; do not trust extension alone.
        if (!png.AsSpan(12, 4).SequenceEqual("IHDR"u8))
        {
            error = "Missing PNG header.";
            return false;
        }
        var width = System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(png.AsSpan(16, 4));
        var height = System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(png.AsSpan(20, 4));
        if (width is < 1 or > 4096 || height is < 1 or > 4096)
        {
            error = "PNG dimensions must be between 1 and 4096 pixels.";
            return false;
        }
        return true;
    }
}
