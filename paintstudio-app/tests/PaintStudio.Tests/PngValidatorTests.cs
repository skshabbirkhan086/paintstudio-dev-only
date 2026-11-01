using PaintStudio.Api.Services;
using Xunit;

namespace PaintStudio.Tests;

public sealed class PngValidatorTests
{
    [Fact]
    public void MissingPayloadIsRejected() => Assert.False(PngValidator.TryDecode(null, out _, out _));

    [Fact]
    public void InvalidBase64IsRejected() => Assert.False(PngValidator.TryDecode("data:image/png;base64,@@@", out _, out _));

    [Fact]
    public void PngWithInvalidDimensionsIsRejected()
    {
        var bytes = new byte[] {137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,0,0,0,0,1};
        Assert.False(PngValidator.TryDecode("data:image/png;base64," + Convert.ToBase64String(bytes), out _, out _));
    }
}
