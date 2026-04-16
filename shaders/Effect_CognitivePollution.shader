Shader "PuddingKC/Effects/CognitivePollution"
{
    Properties
    {
        _Pixelation ("Pixelation", Range(12, 240)) = 72
        _Distortion ("Signal Distortion", Range(0, 0.03)) = 0.006
        _Banding ("Banding Strength", Range(0, 1)) = 0.4
        _Noise ("Noise", Range(0, 0.2)) = 0.045
        _Chromatic ("Chromatic Shift", Range(0, 0.02)) = 0.003
        _ScanlineStrength ("Scanline Strength", Range(0, 1)) = 0.25
        _ColorSteps ("Color Steps", Range(2, 16)) = 6
        _EdgeSoftness ("Edge Softness", Range(0.01, 0.5)) = 0.14
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
            float _Pixelation, _Distortion, _Banding, _Noise, _Chromatic, _ScanlineStrength, _ColorSteps, _EdgeSoftness, _EffectStrength;

            struct appdata
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
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

            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 345.45));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 uv = i.screenPos.xy / i.screenPos.w;
                float t = _Time.y;

                float lineNoise = sin(i.uv.y * 120.0 + t * 8.0) * 0.5 + 0.5;
                float blockNoise = hash21(floor(i.uv * 32.0) + floor(t * 6.0));
                float bandShift = (lineNoise * 2.0 - 1.0) * _Distortion;
                bandShift += (blockNoise - 0.5) * _Distortion * _Banding;

                float2 warpedUV = uv;
                warpedUV.x += bandShift;
                warpedUV.y += sin(i.uv.x * 18.0 + t * 3.5) * _Distortion * 0.35;

                float pixelScale = max(_Pixelation, 1.0);
                float2 pixelUV = floor(warpedUV * pixelScale) / pixelScale;

                fixed4 sampled;
                sampled.r = tex2D(_GrabTexture, pixelUV + float2(_Chromatic, 0)).r;
                sampled.g = tex2D(_GrabTexture, pixelUV).g;
                sampled.b = tex2D(_GrabTexture, pixelUV - float2(_Chromatic, 0)).b;
                sampled.a = 1.0;

                float steps = max(_ColorSteps, 2.0);
                sampled.rgb = floor(sampled.rgb * steps) / steps;

                float grain = (hash21(pixelUV * 64.0 + t) - 0.5) * _Noise;
                float scanline = sin(i.uv.y * 420.0 - t * 14.0) * _ScanlineStrength * 0.08;
                sampled.rgb += grain + scanline;

                fixed3 sickTint = fixed3(0.82, 0.96, 1.08);
                fixed3 warningTint = fixed3(1.08, 0.92, 0.95);
                sampled.rgb *= lerp(sickTint, warningTint, blockNoise * _Banding);
                sampled.rgb = saturate(sampled.rgb);

                float2 boxUV = abs(i.uv - 0.5) * 2.0;
                float edgeDist = max(boxUV.x, boxUV.y);
                float mask = 1.0 - smoothstep(1.0 - _EdgeSoftness, 1.0, edgeDist);
                mask *= _EffectStrength;

                fixed4 original = tex2D(_GrabTexture, uv);
                return lerp(original, sampled, saturate(mask));
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
