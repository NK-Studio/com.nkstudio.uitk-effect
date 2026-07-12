Shader "UIEffects/Gradient"
{
    Properties
    {
        [Header(Gradient)]
        _ColorStart("Start Color", Color) = (0.4, 0.2, 0.9, 1)
        _ColorEnd("End Color", Color) = (1, 0.5, 0.2, 1)
        _Angle("Angle (deg, 0 = left to right)", Float) = 0
        _Steps("Scale (%)", Range(1, 150)) = 150
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "isCustomUITKShader"="true"
            "Queue"="Transparent"
            "ShaderGraphShader"="true"
            "ShaderGraphTargetId"=""
            "IgnoreProjector"="True"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Pass
        {
            Name "Default"

            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM

            #pragma target 3.5
            #pragma vertex uie_custom_vert
            #pragma fragment uie_custom_frag

            #pragma multi_compile_local _ _UIE_FORCE_GAMMA
            #pragma multi_compile_local _ _UIE_TEXTURE_SLOT_COUNT_4 _UIE_TEXTURE_SLOT_COUNT_2 _UIE_TEXTURE_SLOT_COUNT_1
            #pragma multi_compile_local _ _UIE_RENDER_TYPE_SOLID _UIE_RENDER_TYPE_TEXTURE _UIE_RENDER_TYPE_TEXT _UIE_RENDER_TYPE_GRADIENT

            #define UITK_SHADERGRAPH
            #define _SURFACE_TYPE_TRANSPARENT 1
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define ATTRIBUTES_NEED_TEXCOORD1
            #define ATTRIBUTES_NEED_TEXCOORD2
            #define ATTRIBUTES_NEED_TEXCOORD3
            #define ATTRIBUTES_NEED_COLOR
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_TEXCOORD1
            #define VARYINGS_NEED_TEXCOORD3
            #define VARYINGS_NEED_COLOR
            #define FEATURES_GRAPH_VERTEX
            #define SHADERPASS SHADERPASS_CUSTOM_UI

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"

            #undef GLOBAL_CBUFFER_START
            #undef GLOBAL_CBUFFER_END
            #undef CBUFFER_START
            #undef CBUFFER_END
            #undef SAMPLE_DEPTH_TEXTURE
            #undef SAMPLE_DEPTH_TEXTURE_LOD
            #undef UNITY_PRETRANSFORM_TO_DISPLAY_ORIENTATION
            #include "Internal/UnityUIE.cginc"

            struct Attributes
            {
                float3 positionOS : POSITION;
                float4 color : COLOR;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
                float4 uv3 : TEXCOORD3;
                float4 uv4 : TEXCOORD4;
                float4 uv5 : TEXCOORD5;
                float4 uv6 : TEXCOORD6;
                float4 uv7 : TEXCOORD7;
            };

            struct PackedVaryings
            {
                float4 positionCS : SV_POSITION;
                float4 uvClip : TEXCOORD0;
                float4 typeTexSettings : TEXCOORD1;
                float4 textCoreLocLayoutUV : TEXCOORD2;
                float4 circle : TEXCOORD3;
                float4 color : COLOR;
            };

            half4 _TextureSampleAdd;

            CBUFFER_START(UnityPerMaterial)
                float4 _ColorStart;
                float4 _ColorEnd;
                float _Angle;
                float _Steps;
            CBUFFER_END

            float4 DefaultUITKColor(
                float4 tint,
                float4 typeTexSettings,
                float4 uvClip,
                float2 textCoreLoc,
                float4 circle)
            {
                [branch] if (_UIE_RENDER_TYPE_SOLID
                    || _UIE_RENDER_TYPE_ANY && TestType(typeTexSettings.x, k_FragTypeSolid))
                {
                    SolidFragInput input;
                    input.tint = tint;
                    input.isArc = false;
                    input.outer = float2(-10000, -10000);
                    input.inner = float2(-10000, -10000);
                    return uie_std_frag_solid(input).color;
                }
                else [branch] if (_UIE_RENDER_TYPE_TEXTURE
                    || _UIE_RENDER_TYPE_ANY && TestType(typeTexSettings.x, k_FragTypeTexture))
                {
                    TextureFragInput input;
                    input.tint = tint;
                    input.textureSlot = typeTexSettings.y;
                    input.uv = uvClip.xy;
                    input.isArc = false;
                    input.outer = float2(-10000, -10000);
                    input.inner = float2(-10000, -10000);
                    return uie_std_frag_texture(input).color;
                }
                else [branch] if (_UIE_RENDER_TYPE_TEXT
                    || _UIE_RENDER_TYPE_ANY && TestType(typeTexSettings.x, k_FragTypeText))
                {
                    [branch] if (GetTextureInfo(typeTexSettings.y).sdfScale > 0.0)
                    {
                        SdfTextFragInput input;
                        input.tint = tint;
                        input.textureSlot = typeTexSettings.y;
                        input.uv = uvClip.xy;
                        input.extraDilate = circle.x;
                        input.textCoreLoc = round(textCoreLoc);
                        input.opacity = typeTexSettings.z;
                        return uie_std_frag_sdf_text(input).color;
                    }
                    else
                    {
                        BitmapTextFragInput input;
                        input.tint = tint;
                        input.textureSlot = typeTexSettings.y;
                        input.uv = uvClip.xy;
                        input.opacity = typeTexSettings.z;
                        return uie_std_frag_bitmap_text(input).color;
                    }
                }
                else
                {
                    SvgGradientFragInput input;
                    input.settingIndex = round(typeTexSettings.z);
                    input.textureSlot = round(typeTexSettings.y);
                    input.uv = uvClip.xy;
                    input.isArc = false;
                    input.outer = float2(-10000, -10000);
                    input.inner = float2(-10000, -10000);

                    float4 gradientColor = uie_std_frag_svg_gradient(input).color;
                    return gradientColor * tint;
                }
            }

            PackedVaryings uie_custom_vert(Attributes input)
            {
                appdata_t uieInput = (appdata_t)0;
                uieInput.vertex = float4(input.positionOS, 1.0);
                uieInput.color = input.color;
                uieInput.uv = input.uv0;
                uieInput.xformClipPages = input.uv1;
                uieInput.ids = input.uv2;
                uieInput.flags = input.uv3;
                uieInput.opacityColorPages = input.uv4;
                uieInput.settingIndex = input.uv5;
                uieInput.circle = input.uv6;
                uieInput.textureId = input.uv7.x;

                v2f uieOutput = uie_std_vert(uieInput);

                PackedVaryings output = (PackedVaryings)0;
                output.positionCS = uieOutput.pos;
                output.uvClip = uieOutput.uvClip;
                output.typeTexSettings = uieOutput.typeTexSettings;
                output.textCoreLocLayoutUV = float4(uieOutput.textCoreLoc, input.uv0.zw);
                output.circle = uieOutput.circle;
                output.color = uieOutput.color;
                return output;
            }

            UIE_FRAG_T uie_custom_frag(PackedVaryings input) : SV_Target
            {
                float4 baseColor = DefaultUITKColor(
                    input.color,
                    input.typeTexSettings,
                    input.uvClip,
                    input.textCoreLocLayoutUV.xy,
                    input.circle);
                
                
                float2 layoutUV = input.textCoreLocLayoutUV.zw;

                // Angle 0 = left-to-right; layout UV is y-down, so positive angles
                // rotate the gradient axis clockwise on screen.
                float rad = radians(_Angle);
                float2 direction = float2(cos(rad), sin(rad));

                // Normalize the projection so t spans exactly 0..1 across the element
                // for any direction (same normalization as the CSS gradient line).
                float2 projectionMinUV = float2(direction.x < 0.0 ? 1.0 : 0.0,
                                                direction.y < 0.0 ? 1.0 : 0.0);
                float2 projectionMaxUV = 1.0 - projectionMinUV;
                float projectionMin = dot(projectionMinUV, direction);
                float projectionMax = dot(projectionMaxUV, direction);
                float t = saturate((dot(layoutUV, direction) - projectionMin)/ max(projectionMax - projectionMin, 0.0001));

                // Photoshop-style Gradient Overlay scale. 150% is treated as the
                // full linear span used by this shader; lower values compress the
                // blend around the center and clamp the two solid color sides.
                float scalePercent = _Steps <= 0.0 ? 150.0 : clamp(_Steps, 1.0, 150.0);
                t = saturate((t - 0.5) * (150.0 / scalePercent) + 0.5);

                float4 gradient = lerp(_ColorStart, _ColorEnd, t);

#if !UIE_COLORSPACE_GAMMA
                // _ColorStart/_ColorEnd arrive as raw sRGB values from USS prop().
                // UITK converts vertex colors to linear in uie_std_vert, so do the
                // same here or the gradient renders washed out in linear panels.
                // Lerp happens in gamma space above to match the UI Builder preview.
                gradient.rgb = uie_gamma_to_linear(gradient.rgb);
#endif

                // The material only affects this element's own geometry (children render
                // separately), so tinting the base fill is safe for any child content.
                // With a white background-color the gradient shows at full strength.
                float3 color = baseColor.rgb * gradient.rgb;
                float alpha = baseColor.a * gradient.a;

                half renderType = round(input.typeTexSettings.x);
                half isArc = input.typeTexSettings.w;
                float coverage = uie_sg_compute_aa_coverage(
                    renderType,
                    isArc,
                    input.circle.xy,
                    input.circle.zw);
                coverage *= uie_fragment_clip(input.uvClip.zw);
                clip(coverage - 0.003);
                alpha *= coverage;

                return float4(color, alpha);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
