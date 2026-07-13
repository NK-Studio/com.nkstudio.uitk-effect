Shader "UIEffects/OuterGlow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Radius ("Glow Radius (px)", Float) = 12
        _Intensity ("Intensity", Float) = 1
        _GlowColor ("Glow Color", Color) = (1, 1, 0.6, 1)
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

            float _Radius;
            float _Intensity;
            half4 _GlowColor;

            #define GLOW_SAMPLES 48
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
            float SampleAlpha(float2 uv, float4 uvRect)
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

                // No glow when radius or intensity is non-positive; pass the element
                // through untouched instead of computing a zero-strength halo.
                if (_Radius <= 0.0 || _Intensity <= 0.0)
                {
                    #if _UIE_OUTPUT_LINEAR
                    col.rgb = GammaToLinearSpace(col.rgb);
                    #endif
                    return col;
                }

                // Same Vogel-disk gaussian blur as the drop-shadow filter, but sampled
                // in place (no offset) so the halo radiates evenly in every direction.
                float blurAlpha = 0.0;
                float weightSum = 0.0;

                [loop]
                for (int k = 0; k < GLOW_SAMPLES; k++)
                {
                    float r = sqrt((k + 0.5) / GLOW_SAMPLES);
                    float theta = k * GOLDEN_ANGLE;
                    float2 tap = r * float2(cos(theta), sin(theta));
                    float w = exp(-2.0 * r * r);
                    blurAlpha += SampleAlpha(i.uv + tap * _Radius * texel, uvRect) * w;
                    weightSum += w;
                }
                blurAlpha /= weightSum;

                // Only the halo outside the original silhouette; intensity scales how
                // strong/opaque the glow reads without changing its spatial spread.
                float glowAlpha = saturate((blurAlpha - col.a) * _Intensity);

                half shadowA = glowAlpha * _GlowColor.a;
                half4 outCol;
                outCol.rgb = col.rgb + _GlowColor.rgb * shadowA * (1.0 - col.a);
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
