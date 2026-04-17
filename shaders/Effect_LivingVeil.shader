Shader "PuddingKC/Effects/LivingVeil"
{
    Properties
    {
        [HDR] _TintA ("Membrane Tint A", Color) = (0.72, 0.95, 0.88, 1)
        [HDR] _TintB ("Membrane Tint B", Color) = (1.0, 0.76, 0.82, 1)
        _Refraction ("Refraction", Range(0, 0.03)) = 0.006
        _PulseSpeed ("Pulse Speed", Range(0, 8)) = 1.6
        _VeinScale ("Vein Scale", Range(1, 20)) = 8
        _VeinStrength ("Vein Strength", Range(0, 1)) = 0.42
        _Chromatic ("Chromatic Shift", Range(0, 0.02)) = 0.002
        _GlossPulse ("Gloss Pulse", Range(0, 1)) = 0.35
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
            float4 _TintA, _TintB;
            float _Refraction, _PulseSpeed, _VeinScale, _VeinStrength, _Chromatic, _GlossPulse, _EdgeSoftness, _EffectStrength;

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
                p = frac(p * float2(234.34, 435.345));
                p += dot(p, p + 34.23);
                return frac(p.x * p.y);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 uv = i.screenPos.xy / i.screenPos.w;
                float t = _Time.y * _PulseSpeed;

                float2 centered = i.uv - 0.5;
                float radial = length(centered) * 2.0;
                float pulse = sin(t + radial * 8.0) * 0.5 + 0.5;

                float veinA = sin(i.uv.x * _VeinScale * 6.3 + t * 1.3 + sin(i.uv.y * 9.0));
                float veinB = cos(i.uv.y * _VeinScale * 5.1 - t * 1.1 + sin(i.uv.x * 7.0));
                float veinNoise = hash21(floor(i.uv * _VeinScale * 5.0) + floor(t * 2.0));
                float membrane = saturate((veinA * veinB) * 0.5 + 0.5);
                membrane = lerp(membrane, veinNoise, 0.28);

                float2 refractDir = normalize(float2(veinA, veinB) + 0.0001);
                float2 refractUV = uv + refractDir * (_Refraction * (0.45 + pulse * 0.55));

                fixed4 sceneCol;
                sceneCol.r = tex2D(_GrabTexture, refractUV + float2(_Chromatic, 0)).r;
                sceneCol.g = tex2D(_GrabTexture, refractUV).g;
                sceneCol.b = tex2D(_GrabTexture, refractUV - float2(_Chromatic, 0)).b;
                sceneCol.a = 1.0;

                fixed3 membraneTint = lerp(_TintA.rgb, _TintB.rgb, membrane);
                float wetEdge = pow(saturate(1.0 - radial), 2.2);
                float gloss = (sin(t * 1.7 + i.uv.y * 14.0) * 0.5 + 0.5) * _GlossPulse * wetEdge;

                fixed3 finalRgb = lerp(sceneCol.rgb, sceneCol.rgb * membraneTint, _VeinStrength * 0.45);
                finalRgb += membraneTint * gloss * 0.35;
                finalRgb = lerp(finalRgb, membraneTint, _VeinStrength * membrane * 0.18);
                finalRgb = saturate(finalRgb);

                float2 boxUV = abs(i.uv - 0.5) * 2.0;
                float edgeDist = max(boxUV.x, boxUV.y);
                float mask = 1.0 - smoothstep(1.0 - _EdgeSoftness, 1.0, edgeDist);
                mask *= _EffectStrength;

                fixed4 original = tex2D(_GrabTexture, uv);
                return lerp(original, fixed4(finalRgb, 1.0), saturate(mask));
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
