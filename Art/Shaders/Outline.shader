Shader "UIEffects/Outline"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Width ("Outline Width (px)", Float) = 4
        _OutlineColor ("Outline Color", Color) = (1, 1, 1, 1)
        _Mode ("Placement (0=Outside 1=Center 2=Inside)", Float) = 0
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

            float _Width;
            half4 _OutlineColor;
            float _Mode;

            #define OUTLINE_SAMPLES 32
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

                // Outside grows the silhouette outward by the full width, Inside shrinks
                // it inward by the full width, Center splits the width evenly across the
                // edge. Dilation (max) and erosion (min) share the same Vogel-spiral loop;
                // whichever radius is zero for the current mode collapses to a no-op.
                float outerRadius = _Mode < 0.5 ? _Width : (_Mode < 1.5 ? _Width * 0.5 : 0.0);
                float innerRadius = _Mode < 0.5 ? 0.0 : (_Mode < 1.5 ? _Width * 0.5 : _Width);

                float dilated = col.a;
                float eroded = col.a;

                [loop]
                for (int k = 0; k < OUTLINE_SAMPLES; k++)
                {
                    float r = sqrt((k + 0.5) / OUTLINE_SAMPLES);
                    float theta = k * GOLDEN_ANGLE;
                    float2 dir = float2(cos(theta), sin(theta));
                    dilated = max(dilated, SampleAlpha(i.uv + dir * r * outerRadius * texel, uvRect));
                    eroded = min(eroded, SampleAlpha(i.uv + dir * r * innerRadius * texel, uvRect));
                }

                // Ring band spanning from the eroded edge to the dilated edge — for
                // Outside this sits entirely outside the original silhouette, for Inside
                // entirely inside it, for Center straddling both sides.
                float ringAlpha = saturate(dilated - eroded);

                // Standard premultiplied "stroke over original" composite: it extends
                // alpha where the ring reaches outside the original shape (Outside/Center)
                // and simply overpaints where it stays inside (Center/Inside).
                half strokeA = ringAlpha * _OutlineColor.a;
                half4 stroke;
                stroke.a = strokeA;
                stroke.rgb = _OutlineColor.rgb * strokeA;

                half4 outCol;
                outCol.rgb = stroke.rgb + col.rgb * (1.0 - stroke.a);
                outCol.a = stroke.a + col.a * (1.0 - stroke.a);

                #if _UIE_OUTPUT_LINEAR
                outCol.rgb = GammaToLinearSpace(outCol.rgb);
                #endif

                return outCol;
            }
            ENDCG
        }
    }
}
