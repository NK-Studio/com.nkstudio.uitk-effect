using UnityEngine;
using UnityEngine.UIElements;

namespace NKStudio.UITKEffects
{
    /// <summary>
    /// The UITK Effects filters are serialized <see cref="FilterFunctionDefinition"/> assets, which
    /// can only carry static read/write margins. Those margins bound how far past the element's rect
    /// the effect may draw, so a large offset/radius/width gets clipped to the element's inflated box.
    ///
    /// Margin callbacks are C# delegates and cannot be serialized in the asset, so we attach them at
    /// load time to the shared definition instances. This matches Unity's built-in drop-shadow, whose
    /// margins scale with the effect parameters. Two roles are kept distinct:
    ///  - read margins become drawSourceTexOffsets, which SHIFT where the source is sampled. Any
    ///    asymmetry there moves the whole element, so read margins stay symmetric (and can be zero,
    ///    since every shader clips samples outside the element's uvRect to 0).
    ///  - write margins extend the output only toward where the effect actually draws, keeping the
    ///    render target small and clamped under the GPU's max texture size.
    ///
    /// InnerShadow is intentionally not patched: it only recolors pixels inside the existing
    /// silhouette (innerAlpha * col.a), so it never draws past the element and needs no margins.
    /// </summary>
    public static class UITKEffectsMarginPatcher
    {
        // Points reserved for the element itself plus DPI/headroom, so element + margins stays under
        // the GPU's max texture size. Lower this if you run at a high dynamic DPI (the render target
        // is sized in physical pixels = points * dpi).
        const float k_SizeReserve = 2048f;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
#if UNITY_EDITOR
        [UnityEditor.InitializeOnLoadMethod]
#endif
        private static void Patch()
        {
            foreach (var def in Resources.FindObjectsOfTypeAll<FilterFunctionDefinition>())
            {
                if (def.passes == null || def.passes.Length == 0)
                    continue;

                switch (def.filterName)
                {
                    case "ip-drop-shadow":
                        // passes' getter returns the backing array, so this mutates the pass in place.
                        def.passes[0].computeRequiredReadMarginsCallback = ComputeBlurReadMargins;
                        def.passes[0].computeRequiredWriteMarginsCallback = ComputeDropShadowWriteMargins;
                        break;

                    case "outer-glow":
                        def.passes[0].computeRequiredReadMarginsCallback = ZeroMargins;
                        def.passes[0].computeRequiredWriteMarginsCallback = ComputeOuterGlowWriteMargins;
                        break;

                    case "outline":
                        def.passes[0].computeRequiredReadMarginsCallback = ZeroMargins;
                        def.passes[0].computeRequiredWriteMarginsCallback = ComputeOutlineWriteMargins;
                        break;
                }
            }
        }

        // Clamp so element + margins can never exceed the GPU's max texture size: beyond that the
        // target can't be allocated at all (RenderTexture.Create fails), so we cap the effect's
        // extent instead of spamming errors. A parameter past the cap simply stops growing.
        static float MaxMargin()
        {
            // Only one side per axis is ever large, so half the budget per side leaves room for the
            // element plus the reserve on the opposite side.
            return Mathf.Max(0f, SystemInfo.maxTextureSize * 0.5f - k_SizeReserve);
        }

        static float Clamp(float value) => Mathf.Ceil(Mathf.Min(Mathf.Max(0f, value), MaxMargin()));

        static PostProcessingMargins ZeroMargins(FilterFunction func) => new();

        static PostProcessingMargins Symmetric(float margin)
        {
            float m = Clamp(margin);
            return new PostProcessingMargins { left = m, right = m, top = m, bottom = m };
        }

        // DropShadow: symmetric, offset-independent source coverage. The shader derives the shadow
        // from the element's own alpha (samples outside its uvRect read 0), so the source only needs
        // to cover the blur spread. Keeping it symmetric leaves drawSourceTexOffsets balanced, so the
        // element never moves. Parameter layout: 0=offset-x, 1=offset-y, 2=blur-radius, 3=color.
        static PostProcessingMargins ComputeBlurReadMargins(FilterFunction func)
        {
            return Symmetric(Mathf.Max(0f, func.GetParameter(2).floatValue));
        }

        // DropShadow: asymmetric, extend only toward the shadow. DropShadow.shader uses
        // shadowUV = uv - (offsetX, -offsetY), so the shadow lands toward +offsetX (right) and
        // +offsetY (down = the +bottom side in UITK's y-down layout). Blur adds spread on every side.
        // Because only the shadow side grows, a large offset needs the extra room on one side only.
        static PostProcessingMargins ComputeDropShadowWriteMargins(FilterFunction func)
        {
            float offsetX = func.GetParameter(0).floatValue;
            float offsetY = func.GetParameter(1).floatValue;
            float blur = Mathf.Max(0f, func.GetParameter(2).floatValue);

            return new PostProcessingMargins
            {
                left = Clamp(Mathf.Max(0f, -offsetX) + blur),
                right = Clamp(Mathf.Max(0f, offsetX) + blur),
                top = Clamp(Mathf.Max(0f, -offsetY) + blur),
                bottom = Clamp(Mathf.Max(0f, offsetY) + blur),
            };
        }

        // OuterGlow: the halo radiates evenly in every direction by _Radius, so it grows the output
        // symmetrically on all sides. Parameter layout: 0=radius, 1=intensity, 2=color.
        static PostProcessingMargins ComputeOuterGlowWriteMargins(FilterFunction func)
        {
            return Symmetric(Mathf.Max(0f, func.GetParameter(0).floatValue));
        }

        // Outline: only the outward dilation grows the output. Outside(mode 0) extends by the full
        // width, Center(mode 1) by half, Inside(mode 2) not at all. Symmetric on all sides.
        // Parameter layout: 0=width, 1=color, 2=mode.
        static PostProcessingMargins ComputeOutlineWriteMargins(FilterFunction func)
        {
            float width = Mathf.Max(0f, func.GetParameter(0).floatValue);
            float mode = func.GetParameter(2).floatValue;
            float outerRadius = mode < 0.5f ? width : (mode < 1.5f ? width * 0.5f : 0f);
            return Symmetric(outerRadius);
        }
    }
}
