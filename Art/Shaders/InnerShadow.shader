Shader "UIEffects/InnerShadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OffsetX ("Offset X (px)", Float) = 4
        _OffsetY ("Offset Y (px)", Float) = 4
        _BlurRadius ("Blur Radius (px)", Float) = 8
        _ShadowColor ("Shadow Color", Color) = (0, 0, 0, 0.6)
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
            // For inner shadow that "transparent" reading is exactly what we want:
            // both the space outside the element's own silhouette AND outside its
            // atlas cell should count as "outside the shape" when inverted below.
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

                // Sample the *inverted* silhouette (1 = outside the shape) offset toward
                // the light direction and blurred with the same Vogel-disk gaussian used
                // by the other filters. Near an inner edge facing the offset direction,
                // this pulls in "outside" values, producing a shadow band that fades
                // toward the shape's interior.
                float2 shadowUV = i.uv + float2(_OffsetX, -_OffsetY) * texel;

                // Clamp to 0: negative blur would flip every tap to the opposite side of
                // the disk, distorting non-symmetric shapes instead of just sharpening the
                // shadow. 0 already collapses every tap onto shadowUV (a hard edge), so
                // clamping keeps "0 or below" at that same crisp, undistorted look.
                float blurRadius = max(0.0, _BlurRadius);

                float invAlpha = 1.0 - SampleAlpha(shadowUV, uvRect);
                float weightSum = 1.0;

                [loop]
                for (int k = 0; k < SHADOW_SAMPLES; k++)
                {
                    float r = sqrt((k + 0.5) / SHADOW_SAMPLES);
                    float theta = k * GOLDEN_ANGLE;
                    float2 tap = r * float2(cos(theta), sin(theta));
                    float w = exp(-2.0 * r * r);
                    invAlpha += (1.0 - SampleAlpha(shadowUV + tap * blurRadius * texel, uvRect)) * w;
                    weightSum += w;
                }
                invAlpha /= weightSum;

                // Clip to the element's own silhouette — the shadow never grows outside
                // the original shape, it only recolors pixels already covered by it.
                float innerAlpha = saturate(invAlpha) * col.a;

                half shadowA = innerAlpha * _ShadowColor.a;
                half4 outCol;
                outCol.rgb = col.rgb * (1.0 - shadowA) + _ShadowColor.rgb * shadowA * col.a;
                outCol.a = col.a;

                #if _UIE_OUTPUT_LINEAR
                outCol.rgb = GammaToLinearSpace(outCol.rgb);
                #endif

                return outCol;
            }
            ENDCG
        }
    }
}
