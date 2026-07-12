Shader "UIEffects/DropShadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OffsetX ("Offset X (px)", Float) = 4
        _OffsetY ("Offset Y (px)", Float) = 4
        _BlurRadius ("Blur Radius (px)", Float) = 4
        _ShadowColor ("Shadow Color", Color) = (0, 0, 0, 0.5)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Blend One Zero
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _UIE_OUTPUT_LINEAR

            #include "UnityCG.cginc"
            #include "UnityUIEFilter.cginc"

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                uint rectIndex : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;

            float _OffsetX;
            float _OffsetY;
            float _BlurRadius;
            half4 _ShadowColor;

            #define SHADOW_SAMPLES 48
            #define GOLDEN_ANGLE 2.39996323

            v2f vert (FilterVertexInput v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.rectIndex = GetFilterRectIndex(v);
                return o;
            }

            // The filter source lives in a sub-rect of an atlas; anything sampled
            // outside that rect belongs to another element and must read as transparent.
            float SampleShadowAlpha(float2 uv, float4 uvRect)
            {
                float inside = step(uvRect.x, uv.x) * step(uv.x, uvRect.x + uvRect.z)
                             * step(uvRect.y, uv.y) * step(uv.y, uvRect.y + uvRect.w);
                return tex2D(_MainTex, uv).a * inside;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 uvRect = GetFilterUVRect(i.rectIndex);
                float2 texel = _MainTex_TexelSize.xy;

                half4 col = tex2D(_MainTex, i.uv);

                // Positive Y offset moves the shadow down, matching CSS drop-shadow.
                float2 shadowUV = i.uv - float2(_OffsetX, -_OffsetY) * texel;

                // Vogel disk: golden-angle spiral covers the disc uniformly with no
                // dominant center tap, so density holds up at large blur radii.
                float blurAlpha = 0.0;
                float weightSum = 0.0;

                [loop]
                for (int k = 0; k < SHADOW_SAMPLES; k++)
                {
                    float r = sqrt((k + 0.5) / SHADOW_SAMPLES);
                    float theta = k * GOLDEN_ANGLE;
                    float2 tap = r * float2(cos(theta), sin(theta));
                    float w = exp(-2.0 * r * r);
                    blurAlpha += SampleShadowAlpha(shadowUV + tap * _BlurRadius * texel, uvRect) * w;
                    weightSum += w;
                }
                blurAlpha /= weightSum;

                // _MainTex is premultiplied, so composite "source over shadow" in premultiplied space.
                half shadowA = blurAlpha * _ShadowColor.a;
                half4 outCol;
                outCol.rgb = col.rgb + _ShadowColor.rgb * shadowA * (1.0 - col.a);
                outCol.a = col.a + shadowA * (1.0 - col.a);

                #if _UIE_OUTPUT_LINEAR
                outCol.rgb = GammaToLinearSpace(outCol.rgb);
                #endif

                return outCol;
            }
            ENDCG
        }
    }
}
