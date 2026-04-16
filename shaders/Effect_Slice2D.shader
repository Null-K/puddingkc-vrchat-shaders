Shader "PuddingKC/Effects/Slice2D"
{
    Properties
    {
        _SliceCount ("Slice Count", Range(4, 80)) = 22
        _SliceGap ("Slice Gap", Range(0, 0.12)) = 0.015
        _SliceJitter ("Slice Jitter", Range(0, 0.08)) = 0.01
        _DriftSpeed ("Drift Speed", Range(0, 8)) = 1.8
        _BlurSize ("Blur Size", Range(0.001, 0.03)) = 0.008
        _GhostStrength ("Ghost Strength", Range(0, 1)) = 0.3
        _EdgeSoftness ("Edge Softness", Range(0.01, 0.5)) = 0.12
        _EffectStrength ("Effect Strength", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
        GrabPass { "_GrabTexture" }

        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _GrabTexture;
            float4 _GrabTexture_TexelSize;
            float _SliceCount, _SliceGap, _SliceJitter, _DriftSpeed, _BlurSize, _GhostStrength, _EdgeSoftness, _EffectStrength;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float2 uv : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeGrabScreenPos(o.vertex);
                o.uv = v.uv;
                return o;
            }

            float hash(float n)
            {
                return frac(sin(n) * 43758.5453);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 uv = i.screenPos.xy / i.screenPos.w;
                float t = _Time.y * _DriftSpeed;

                float sliceIndex = floor(i.uv.y * _SliceCount);
                float normalizedSlice = sliceIndex / max(_SliceCount - 1.0, 1.0);
                float randomOffset = (hash(sliceIndex * 17.13 + floor(t * 2.0)) - 0.5) * 2.0;
                float wave = sin(normalizedSlice * 21.0 + t * 1.7);
                float sliceOffset = wave * _SliceGap + randomOffset * _SliceJitter;

                float2 slicedUV = uv + float2(sliceOffset, 0.0);

                fixed4 baseCol = tex2D(_GrabTexture, slicedUV);

                fixed4 blurCol = 0;
                const int SAMPLE_COUNT = 8;
                for (int j = 0; j < SAMPLE_COUNT; j++)
                {
                    float angle = 6.2831853 * j / SAMPLE_COUNT;
                    float2 dir = float2(cos(angle), sin(angle));
                    blurCol += tex2D(_GrabTexture, slicedUV + dir * _BlurSize);
                }
                blurCol /= SAMPLE_COUNT;

                float2 ghostUV = slicedUV + float2(_GrabTexture_TexelSize.x * 10.0, 0.0);
                fixed4 ghostCol = tex2D(_GrabTexture, ghostUV);

                fixed4 finalCol = lerp(baseCol, blurCol, 0.45);
                finalCol.rgb = lerp(finalCol.rgb, ghostCol.rgb, _GhostStrength * 0.35);

                float2 boxUV = abs(i.uv - 0.5) * 2.0;
                float edgeDist = max(boxUV.x, boxUV.y);
                float mask = 1.0 - smoothstep(1.0 - _EdgeSoftness, 1.0, edgeDist);
                mask *= _EffectStrength;

                fixed4 original = tex2D(_GrabTexture, uv);
                return lerp(original, finalCol, saturate(mask));
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
